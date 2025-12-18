const std = @import("std");
const utils = @import("utils.zig");
const c = @cImport({
    @cInclude("pulse/simple.h");
    @cInclude("pulse/error.h");
});

/// WAV file header structures
/// IMPORTANT: extern struct for C-compatible memory layout (no padding)
const WavHeader = extern struct {
    // RIFF chunk descriptor
    riff_header: [4]u8 = "RIFF".*,
    wav_size: u32 = 0, // File size - 8
    wave_header: [4]u8 = "WAVE".*,

    // fmt subchunk
    fmt_header: [4]u8 = "fmt ".*,
    fmt_chunk_size: u32 = 16,
    audio_format: u16 = 1, // PCM
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    sample_alignment: u16,
    bit_depth: u16,

    // data subchunk
    data_header: [4]u8 = "data".*,
    data_bytes: u32 = 0,

    fn create(sample_rate: u32, channels: u16, bit_depth: u16) WavHeader {
        const byte_rate = sample_rate * channels * (bit_depth / 8);
        const sample_alignment = channels * (bit_depth / 8);

        return .{
            .num_channels = channels,
            .sample_rate = sample_rate,
            .byte_rate = byte_rate,
            .sample_alignment = sample_alignment,
            .bit_depth = bit_depth,
        };
    }

    fn updateSizes(self: *WavHeader, data_size: u32) void {
        self.data_bytes = data_size;
        self.wav_size = data_size + 36; // 36 = size of header minus 8 bytes (RIFF header + size field)
    }
};

/// Audio recorder using PulseAudio Simple API
pub const AudioRecorder = struct {
    allocator: std.mem.Allocator,
    sample_rate: u32 = 16000,
    channels: u8 = 1,
    bit_depth: u16 = 16,
    recording: bool = false,

    // PulseAudio
    pa_stream: ?*c.pa_simple = null,

    // File handling
    output_file: ?std.fs.File = null,
    output_path: ?[]u8 = null,
    bytes_recorded: u32 = 0,

    // Audio level tracking
    level_buffer: [4096]i16 = undefined,
    level_buffer_size: usize = 0,

    pub fn init(allocator: std.mem.Allocator) AudioRecorder {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AudioRecorder) void {
        if (self.pa_stream) |stream| {
            c.pa_simple_free(stream);
            self.pa_stream = null;
        }

        if (self.output_file) |file| {
            file.close();
            self.output_file = null;
        }

        if (self.output_path) |path| {
            self.allocator.free(path);
            self.output_path = null;
        }
    }

    /// Start recording audio to a WAV file
    /// device_name: PulseAudio device name (null or empty = use default)
    pub fn startRecording(self: *AudioRecorder, output_path: []const u8, device_name: ?[]const u8) !void {
        if (self.recording) {
            return error.AlreadyRecording;
        }

        // Store output path
        self.output_path = try self.allocator.dupe(u8, output_path);
        errdefer {
            self.allocator.free(self.output_path.?);
            self.output_path = null;
        }

        // Create output file
        self.output_file = try std.fs.cwd().createFile(output_path, .{ .read = true });
        errdefer {
            self.output_file.?.close();
            self.output_file = null;
        }

        // Write WAV header (will update sizes on stop)
        var header = WavHeader.create(self.sample_rate, self.channels, self.bit_depth);
        const header_bytes = std.mem.asBytes(&header);
        try self.output_file.?.writeAll(header_bytes);

        // Initialize PulseAudio
        var sample_spec = c.pa_sample_spec{
            .format = c.PA_SAMPLE_S16LE, // 16-bit signed little-endian
            .rate = self.sample_rate,
            .channels = self.channels,
        };

        // Determine which device to use
        const device_ptr = if (device_name) |name|
            if (name.len > 0) name.ptr else null
        else
            null;

        var error_code: c_int = 0;
        self.pa_stream = c.pa_simple_new(
            null, // Use default server
            "Talkies", // Application name
            c.PA_STREAM_RECORD, // Record stream
            device_ptr, // Device (null = default)
            "Voice Recording", // Stream description
            &sample_spec,
            null, // Use default channel map
            null, // Use default buffering attributes
            &error_code,
        );

        if (self.pa_stream == null) {
            const err_str = c.pa_strerror(error_code);
            utils.log("PulseAudio error: {s}", .{err_str});
            return error.PulseAudioInitFailed;
        }

        self.recording = true;
        self.bytes_recorded = 0;
        self.level_buffer_size = 0;

        utils.log("Audio recording started: {s} (16kHz, mono, 16-bit)", .{output_path});
    }

    /// Record a chunk of audio data
    pub fn recordChunk(self: *AudioRecorder) !bool {
        if (!self.recording) {
            return false;
        }

        const buffer_size: usize = 4096;
        var buffer: [buffer_size]u8 = undefined;

        var error_code: c_int = 0;
        const result = c.pa_simple_read(
            self.pa_stream,
            &buffer,
            buffer_size,
            &error_code,
        );

        if (result < 0) {
            const err_str = c.pa_strerror(error_code);
            utils.log("PulseAudio read error: {s}", .{err_str});
            return error.PulseAudioReadFailed;
        }

        // Write to file
        try self.output_file.?.writeAll(&buffer);
        self.bytes_recorded += buffer_size;

        // Update level buffer for RMS calculation
        const samples = std.mem.bytesAsSlice(i16, &buffer);
        const copy_size = @min(samples.len, self.level_buffer.len);
        @memcpy(self.level_buffer[0..copy_size], samples[0..copy_size]);
        self.level_buffer_size = copy_size;

        return true;
    }

    /// Stop recording and finalize the WAV file
    pub fn stopRecording(self: *AudioRecorder) !void {
        if (!self.recording) {
            return;
        }

        self.recording = false;

        // Drain PulseAudio buffer
        if (self.pa_stream) |stream| {
            var error_code: c_int = 0;
            _ = c.pa_simple_drain(stream, &error_code);
            c.pa_simple_free(stream);
            self.pa_stream = null;
        }

        // Update WAV header with actual sizes
        if (self.output_file) |file| {
            try file.seekTo(0);
            var header = WavHeader.create(self.sample_rate, self.channels, self.bit_depth);
            header.updateSizes(self.bytes_recorded);
            const header_bytes = std.mem.asBytes(&header);
            try file.writeAll(header_bytes);
            file.close();
            self.output_file = null;
        }

        utils.log("Audio recording stopped: {} bytes recorded", .{self.bytes_recorded});

        if (self.output_path) |path| {
            self.allocator.free(path);
            self.output_path = null;
        }
    }

    /// Get current audio level (RMS)
    pub fn getAudioLevel(self: *AudioRecorder) f32 {
        if (self.level_buffer_size == 0) {
            return 0.0;
        }

        var sum: f64 = 0.0;
        for (self.level_buffer[0..self.level_buffer_size]) |sample| {
            const normalized = @as(f64, @floatFromInt(sample)) / 32768.0;
            sum += normalized * normalized;
        }

        const rms = @sqrt(sum / @as(f64, @floatFromInt(self.level_buffer_size)));
        return @floatCast(rms);
    }
};

test "audio recorder initialization" {
    const allocator = std.testing.allocator;
    var recorder = AudioRecorder.init(allocator);
    defer recorder.deinit();

    try std.testing.expect(recorder.sample_rate == 16000);
    try std.testing.expect(recorder.channels == 1);
    try std.testing.expect(recorder.bit_depth == 16);
    try std.testing.expect(recorder.recording == false);
}

test "WAV header creation" {
    const header = WavHeader.create(16000, 1, 16);

    // Check RIFF header
    try std.testing.expectEqualSlices(u8, "RIFF", &header.riff_header);
    try std.testing.expectEqualSlices(u8, "WAVE", &header.wave_header);
    try std.testing.expectEqualSlices(u8, "fmt ", &header.fmt_header);
    try std.testing.expectEqualSlices(u8, "data", &header.data_header);

    // Check format
    try std.testing.expect(header.audio_format == 1); // PCM
    try std.testing.expect(header.num_channels == 1);
    try std.testing.expect(header.sample_rate == 16000);
    try std.testing.expect(header.bit_depth == 16);

    // Check calculated values
    const expected_byte_rate = 16000 * 1 * 2; // sample_rate * channels * (bit_depth/8)
    try std.testing.expect(header.byte_rate == expected_byte_rate);

    const expected_alignment: u16 = 1 * 2; // channels * (bit_depth/8)
    try std.testing.expect(header.sample_alignment == expected_alignment);
}

test "WAV header size update" {
    var header = WavHeader.create(16000, 1, 16);

    const data_size: u32 = 32000; // 1 second of audio
    header.updateSizes(data_size);

    try std.testing.expect(header.data_bytes == data_size);
    try std.testing.expect(header.wav_size == data_size + 36);
}

test "audio level calculation" {
    const allocator = std.testing.allocator;
    var recorder = AudioRecorder.init(allocator);
    defer recorder.deinit();

    // Test with no data
    const level_empty = recorder.getAudioLevel();
    try std.testing.expect(level_empty == 0.0);

    // Test with known samples
    recorder.level_buffer[0] = 16384; // Half of max (32768)
    recorder.level_buffer[1] = -16384;
    recorder.level_buffer_size = 2;

    const level = recorder.getAudioLevel();
    try std.testing.expect(level > 0.4 and level < 0.6); // Approximately 0.5
}
