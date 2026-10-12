const std = @import("std");
const utils = @import("core").utils;
const wav_format = @import("core").wav;
const vad = @import("vad.zig");

/// WAV file header structure (44 bytes)
const WavHeader = extern struct {
    riff_header: [4]u8,
    wav_size: u32,
    wave_header: [4]u8,
    fmt_header: [4]u8,
    fmt_chunk_size: u32,
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    sample_alignment: u16,
    bit_depth: u16,
    data_header: [4]u8,
    data_bytes: u32,
};

/// Read a 16-bit PCM WAV file. Caller owns `samples`.
pub fn readWavFile(allocator: std.mem.Allocator, path: []const u8) !struct {
    samples: []i16,
    sample_rate: u32,
    channels: u16,
} {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(utils.io(), path, allocator, .limited(1024 * 1024 * 1024));
    defer allocator.free(bytes);
    const parsed = try wav_format.parse(bytes);

    const samples = try allocator.alloc(i16, parsed.data.len / 2);
    for (samples, 0..) |*sample, i| {
        sample.* = std.mem.readInt(i16, parsed.data[i * 2 ..][0..2], .little);
    }
    return .{
        .samples = samples,
        .sample_rate = parsed.format.sample_rate,
        .channels = parsed.format.channels,
    };
}

/// Write WAV file from PCM samples
pub fn writeWavFile(path: []const u8, samples: []const i16, sample_rate: u32, channels: u16) !void {
    const file_io = utils.io();
    const file = try std.Io.Dir.cwd().createFile(file_io, path, .{});
    defer file.close(file_io);

    // Create WAV header
    const data_bytes = @as(u32, @intCast(samples.len * 2)); // 16-bit = 2 bytes per sample
    const byte_rate = sample_rate * channels * 2;
    const sample_alignment = channels * 2;

    const header = WavHeader{
        .riff_header = "RIFF".*,
        .wav_size = data_bytes + 36,
        .wave_header = "WAVE".*,
        .fmt_header = "fmt ".*,
        .fmt_chunk_size = 16,
        .audio_format = 1, // PCM
        .num_channels = channels,
        .sample_rate = sample_rate,
        .byte_rate = byte_rate,
        .sample_alignment = sample_alignment,
        .bit_depth = 16,
        .data_header = "data".*,
        .data_bytes = data_bytes,
    };

    // Write header
    const header_bytes = std.mem.asBytes(&header);
    try file.writeStreamingAll(file_io, header_bytes);

    // Write PCM data
    const data_bytes_slice = std.mem.sliceAsBytes(samples);
    try file.writeStreamingAll(file_io, data_bytes_slice);
}

/// Process WAV file with VAD to trim silence
/// Creates a new trimmed WAV file at output_path
/// Returns true if voice was detected, false if completely silent
pub fn trimSilenceFromWav(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
    vad_mode: vad.VadMode,
) !bool {
    // Read input WAV file
    const wav = try readWavFile(allocator, input_path);
    defer allocator.free(wav.samples);

    utils.log("Processing WAV: {} samples, {}Hz, {} channels", .{
        wav.samples.len,
        wav.sample_rate,
        wav.channels,
    });

    // Initialize VAD
    var voice_detector = try vad.VoiceActivityDetector.init(allocator, wav.sample_rate, vad_mode);
    defer voice_detector.deinit();

    // Trim silence (use 20ms frames for good accuracy/performance balance)
    const trimmed = try voice_detector.trimSilence(wav.samples, 20);

    if (trimmed.len == 0) {
        utils.log("VAD: No voice detected in audio", .{});
        return false;
    }

    const silence_removed = wav.samples.len - trimmed.len;
    const percent_removed = (@as(f32, @floatFromInt(silence_removed)) / @as(f32, @floatFromInt(wav.samples.len))) * 100.0;

    utils.log("VAD: Trimmed {} samples ({d:.1}% of original)", .{ silence_removed, percent_removed });

    // Write trimmed audio to output file
    try writeWavFile(output_path, trimmed, wav.sample_rate, wav.channels);

    return true;
}

test "read and write WAV file" {
    const allocator = std.testing.allocator;

    // Create test samples
    const test_samples = [_]i16{ 1000, 2000, 3000, -1000, -2000 };

    // Write test WAV
    const test_path = "/tmp/test_audio_processing.wav";
    try writeWavFile(test_path, &test_samples, 16000, 1);

    // Read it back
    const wav = try readWavFile(allocator, test_path);
    defer allocator.free(wav.samples);

    try std.testing.expectEqual(@as(u32, 16000), wav.sample_rate);
    try std.testing.expectEqual(@as(u16, 1), wav.channels);
    try std.testing.expectEqual(@as(usize, 5), wav.samples.len);
    try std.testing.expectEqualSlices(i16, &test_samples, wav.samples);

    // Cleanup
    std.Io.Dir.cwd().deleteFile(utils.io(), test_path) catch {};
}
