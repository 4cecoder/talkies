const std = @import("std");
const utils = @import("utils.zig");

/// Whisper transcription service using whisper.cpp
pub const WhisperService = struct {
    allocator: std.mem.Allocator,
    model_path: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) WhisperService {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WhisperService) void {
        if (self.model_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Load a whisper model from disk
    pub fn loadModel(self: *WhisperService, model_name: []const u8) !void {
        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);

        const model_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/models/ggml-{s}.bin",
            .{ data_dir, model_name },
        );

        // TODO: Check if model exists
        // TODO: Load model with whisper.cpp C API

        self.model_path = model_path;
        utils.log("Loaded model: {s}", .{model_name});
    }

    /// Transcribe an audio file
    pub fn transcribe(self: *WhisperService, audio_path: []const u8) ![]const u8 {
        _ = audio_path;
        // TODO: Call whisper.cpp to transcribe audio
        // TODO: Process segments and concatenate text
        // TODO: Return allocated string with transcription
        return try self.allocator.dupe(u8, "Transcription not yet implemented");
    }

    /// Download a model if it doesn't exist
    pub fn downloadModel(self: *WhisperService, model_name: []const u8) !void {
        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);

        const models_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/models",
            .{data_dir},
        );
        defer self.allocator.free(models_dir);

        try utils.ensureDir(models_dir);

        // TODO: Download model from huggingface or other source
        // TODO: Show progress
        utils.log("Downloading model: {s}", .{model_name});
    }
};

test "whisper service initialization" {
    const allocator = std.testing.allocator;
    var service = WhisperService.init(allocator);
    defer service.deinit();

    try std.testing.expect(service.model_path == null);
}
