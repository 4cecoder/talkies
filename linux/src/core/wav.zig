//! RIFF/WAVE parsing and conversion to Whisper's input format
//! (16 kHz mono f32). Pure functions over bytes, so they are testable
//! without audio hardware.

const std = @import("std");

pub const Error = error{
    InvalidWavFile,
    UnsupportedAudioFormat,
    UnsupportedBitDepth,
    MissingFormatChunk,
    MissingDataChunk,
} || std.mem.Allocator.Error;

pub const Format = struct {
    sample_rate: u32,
    channels: u16,
    bits_per_sample: u16,
};

pub const Parsed = struct {
    format: Format,
    /// Interleaved little-endian PCM bytes; borrows from the input.
    data: []const u8,
};

const pcm_format: u16 = 1;
const extensible_format: u16 = 0xFFFE;

/// Walk the RIFF chunk list instead of assuming a 44-byte header, so files
/// with LIST/fact/JUNK chunks (most editors write them) parse correctly.
pub fn parse(bytes: []const u8) Error!Parsed {
    if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "WAVE")) {
        return error.InvalidWavFile;
    }

    var format: ?Format = null;
    var offset: usize = 12;
    while (offset + 8 <= bytes.len) {
        const id = bytes[offset..][0..4];
        const declared: usize = std.mem.readInt(u32, bytes[offset + 4 ..][0..4], .little);
        const body_start = offset + 8;
        // Recorders that crash before finalizing leave a size of 0 or
        // 0xFFFFFFFF on the data chunk; treat it as "to end of file".
        const size = @min(declared, bytes.len - body_start);
        const body = bytes[body_start..][0..size];

        if (std.mem.eql(u8, id, "fmt ")) {
            if (body.len < 16) return error.InvalidWavFile;
            const audio_format = std.mem.readInt(u16, body[0..2], .little);
            if (audio_format != pcm_format and audio_format != extensible_format) return error.UnsupportedAudioFormat;
            format = .{
                .channels = std.mem.readInt(u16, body[2..4], .little),
                .sample_rate = std.mem.readInt(u32, body[4..8], .little),
                .bits_per_sample = std.mem.readInt(u16, body[14..16], .little),
            };
        } else if (std.mem.eql(u8, id, "data")) {
            const fmt = format orelse return error.MissingFormatChunk;
            if (fmt.bits_per_sample != 16) return error.UnsupportedBitDepth;
            if (fmt.channels == 0 or fmt.sample_rate == 0) return error.InvalidWavFile;
            const data_len = if (declared == 0) bytes.len - body_start else size;
            return .{ .format = fmt, .data = bytes[body_start..][0..data_len] };
        }
        // Chunks are word-aligned.
        offset = body_start + size + (size & 1);
    }
    return if (format == null) error.MissingFormatChunk else error.MissingDataChunk;
}

/// Convert 16-bit PCM to mono f32 at `target_rate` (linear resampling).
/// Caller owns the returned slice.
pub fn toMonoF32(allocator: std.mem.Allocator, parsed: Parsed, target_rate: u32) Error![]f32 {
    const channels: usize = parsed.format.channels;
    const frame_bytes = channels * 2;
    const frames = parsed.data.len / frame_bytes;

    const mono = try allocator.alloc(f32, frames);
    defer allocator.free(mono);
    for (0..frames) |frame| {
        var sum: f32 = 0;
        for (0..channels) |ch| {
            const at = frame * frame_bytes + ch * 2;
            const sample = std.mem.readInt(i16, parsed.data[at..][0..2], .little);
            sum += @as(f32, @floatFromInt(sample)) / 32768.0;
        }
        mono[frame] = sum / @as(f32, @floatFromInt(channels));
    }

    if (parsed.format.sample_rate == target_rate or frames == 0) {
        return allocator.dupe(f32, mono);
    }

    const ratio = @as(f64, @floatFromInt(parsed.format.sample_rate)) / @as(f64, @floatFromInt(target_rate));
    const out_len: usize = @intFromFloat(@floor(@as(f64, @floatFromInt(frames)) / ratio));
    const out = try allocator.alloc(f32, out_len);
    for (out, 0..) |*sample, i| {
        const pos = @as(f64, @floatFromInt(i)) * ratio;
        const left: usize = @intFromFloat(@floor(pos));
        const right = @min(left + 1, frames - 1);
        const t: f32 = @floatCast(pos - @floor(pos));
        sample.* = mono[left] * (1 - t) + mono[right] * t;
    }
    return out;
}

fn buildWav(allocator: std.mem.Allocator, channels: u16, rate: u32, extra_chunk: bool, samples: []const i16) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const w = struct {
        fn int(list: *std.ArrayList(u8), a: std.mem.Allocator, comptime T: type, v: T) !void {
            var buf: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &buf, v, .little);
            try list.appendSlice(a, &buf);
        }
    };
    try out.appendSlice(allocator, "RIFF");
    try w.int(&out, allocator, u32, 0);
    try out.appendSlice(allocator, "WAVE");
    try out.appendSlice(allocator, "fmt ");
    try w.int(&out, allocator, u32, 16);
    try w.int(&out, allocator, u16, 1);
    try w.int(&out, allocator, u16, channels);
    try w.int(&out, allocator, u32, rate);
    try w.int(&out, allocator, u32, rate * channels * 2);
    try w.int(&out, allocator, u16, channels * 2);
    try w.int(&out, allocator, u16, 16);
    if (extra_chunk) {
        try out.appendSlice(allocator, "LIST");
        try w.int(&out, allocator, u32, 5); // odd size -> padded
        try out.appendSlice(allocator, "INFO!\x00");
    }
    try out.appendSlice(allocator, "data");
    try w.int(&out, allocator, u32, @intCast(samples.len * 2));
    for (samples) |s| try w.int(&out, allocator, i16, s);
    return out.toOwnedSlice(allocator);
}

test "parses past LIST chunks with odd padding" {
    const allocator = std.testing.allocator;
    const bytes = try buildWav(allocator, 1, 16000, true, &.{ 100, -100, 32767 });
    defer allocator.free(bytes);
    const parsed = try parse(bytes);
    try std.testing.expectEqual(@as(u32, 16000), parsed.format.sample_rate);
    try std.testing.expectEqual(@as(usize, 6), parsed.data.len);
}

test "stereo is downmixed and 32 kHz is resampled to 16 kHz" {
    const allocator = std.testing.allocator;
    const bytes = try buildWav(allocator, 2, 32000, false, &.{ 16384, 0, 16384, 0, -16384, 0, -16384, 0 });
    defer allocator.free(bytes);
    const samples = try toMonoF32(allocator, try parse(bytes), 16000);
    defer allocator.free(samples);
    try std.testing.expectEqual(@as(usize, 2), samples.len);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), samples[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.25), samples[1], 0.001);
}

test "rejects non-PCM and non-16-bit audio" {
    const allocator = std.testing.allocator;
    const bytes = try buildWav(allocator, 1, 16000, false, &.{1});
    defer allocator.free(bytes);
    bytes[20] = 3; // IEEE float
    try std.testing.expectError(error.UnsupportedAudioFormat, parse(bytes));
    bytes[20] = 1;
    bytes[34] = 24;
    try std.testing.expectError(error.UnsupportedBitDepth, parse(bytes));
    try std.testing.expectError(error.InvalidWavFile, parse("not a wav file"));
}
