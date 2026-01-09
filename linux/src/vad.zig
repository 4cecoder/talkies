const std = @import("std");
const utils = @import("utils.zig");

// Import libfvad C API
const c = @cImport({
    @cInclude("fvad.h");
});

/// Voice Activity Detection modes (aggressiveness levels)
pub const VadMode = enum(c_int) {
    quality = 0, // Highest quality, least aggressive
    low_bitrate = 1, // Balanced for low bitrate
    aggressive = 2, // Aggressive filtering
    very_aggressive = 3, // Most aggressive, may cut speech

    pub fn toInt(self: VadMode) c_int {
        return @intFromEnum(self);
    }
};

/// Voice Activity Detector using WebRTC VAD (libfvad)
pub const VoiceActivityDetector = struct {
    allocator: std.mem.Allocator,
    vad: ?*c.Fvad = null,
    sample_rate: u32,
    mode: VadMode,

    pub fn init(allocator: std.mem.Allocator, sample_rate: u32, mode: VadMode) !VoiceActivityDetector {
        // Validate sample rate
        if (sample_rate != 8000 and sample_rate != 16000 and sample_rate != 32000 and sample_rate != 48000) {
            utils.log("Invalid VAD sample rate: {} (must be 8000/16000/32000/48000)", .{sample_rate});
            return error.InvalidSampleRate;
        }

        var self = VoiceActivityDetector{
            .allocator = allocator,
            .sample_rate = sample_rate,
            .mode = mode,
        };

        // Create VAD instance
        self.vad = c.fvad_new();
        if (self.vad == null) {
            utils.log("Failed to create VAD instance", .{});
            return error.VadInitFailed;
        }

        // Configure sample rate
        if (c.fvad_set_sample_rate(self.vad, @intCast(sample_rate)) != 0) {
            c.fvad_free(self.vad);
            utils.log("Failed to set VAD sample rate: {}", .{sample_rate});
            return error.VadConfigFailed;
        }

        // Configure mode (aggressiveness)
        if (c.fvad_set_mode(self.vad, mode.toInt()) != 0) {
            c.fvad_free(self.vad);
            utils.log("Failed to set VAD mode: {}", .{mode.toInt()});
            return error.VadConfigFailed;
        }

        utils.log("VAD initialized (sample_rate: {}Hz, mode: {})", .{ sample_rate, mode.toInt() });
        return self;
    }

    pub fn deinit(self: *VoiceActivityDetector) void {
        if (self.vad) |vad| {
            c.fvad_free(vad);
            self.vad = null;
        }
    }

    /// Process an audio frame and detect voice activity
    /// frame: 16-bit PCM samples
    /// frame_ms: Frame duration in milliseconds (10, 20, or 30)
    /// Returns: true if voice detected, false if silence
    pub fn processFrame(self: *VoiceActivityDetector, frame: []const i16, frame_ms: u32) !bool {
        if (self.vad == null) {
            return error.VadNotInitialized;
        }

        // Validate frame length
        const expected_samples = (self.sample_rate * frame_ms) / 1000;
        if (frame.len != expected_samples) {
            utils.log("Invalid VAD frame length: {} (expected {})", .{ frame.len, expected_samples });
            return error.InvalidFrameLength;
        }

        const result = c.fvad_process(self.vad, frame.ptr, frame.len);
        if (result < 0) {
            return error.VadProcessFailed;
        }

        return result == 1; // 1 = voice, 0 = silence
    }

    /// Find the first voice activity in an audio buffer
    /// Returns the sample index where voice starts, or null if no voice found
    pub fn findVoiceStart(self: *VoiceActivityDetector, samples: []const i16, frame_ms: u32) !?usize {
        const frame_samples = (self.sample_rate * frame_ms) / 1000;
        var offset: usize = 0;

        while (offset + frame_samples <= samples.len) : (offset += frame_samples) {
            const frame = samples[offset .. offset + frame_samples];
            if (try self.processFrame(frame, frame_ms)) {
                return offset;
            }
        }

        return null;
    }

    /// Find the last voice activity in an audio buffer
    /// Returns the sample index where voice ends, or null if no voice found
    pub fn findVoiceEnd(self: *VoiceActivityDetector, samples: []const i16, frame_ms: u32) !?usize {
        const frame_samples = (self.sample_rate * frame_ms) / 1000;

        // Scan backwards from end
        var offset: isize = @as(isize, @intCast(samples.len)) - @as(isize, @intCast(frame_samples));
        while (offset >= 0) : (offset -= @intCast(frame_samples)) {
            const uoffset: usize = @intCast(offset);
            const frame = samples[uoffset .. uoffset + frame_samples];
            if (try self.processFrame(frame, frame_ms)) {
                return uoffset + frame_samples; // Return end of voice frame
            }
        }

        return null;
    }

    /// Trim silence from start and end of audio buffer
    /// Returns a slice with silence removed, or original if no voice found
    pub fn trimSilence(self: *VoiceActivityDetector, samples: []const i16, frame_ms: u32) ![]const i16 {
        const voice_start = try self.findVoiceStart(samples, frame_ms);
        if (voice_start == null) {
            // No voice detected at all
            return samples[0..0]; // Return empty slice
        }

        const voice_end = try self.findVoiceEnd(samples, frame_ms);
        if (voice_end == null) {
            // Voice at start but not at end (shouldn't happen)
            return samples[voice_start.? ..];
        }

        return samples[voice_start.? .. voice_end.?];
    }
};

test "VAD initialization" {
    const allocator = std.testing.allocator;
    var vad = try VoiceActivityDetector.init(allocator, 16000, .quality);
    defer vad.deinit();

    try std.testing.expect(vad.vad != null);
    try std.testing.expect(vad.sample_rate == 16000);
}

test "VAD invalid sample rate" {
    const allocator = std.testing.allocator;
    const result = VoiceActivityDetector.init(allocator, 44100, .quality);
    try std.testing.expectError(error.InvalidSampleRate, result);
}
