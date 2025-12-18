const std = @import("std");
const utils = @import("utils.zig");

// C FFI bindings for whisper.cpp
const c = @cImport({
    @cInclude("whisper.h");
});

/// Whisper model URLs from Hugging Face
const ModelUrls = std.StaticStringMap([]const u8).initComptime(.{
    .{ "tiny", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin" },
    .{ "base", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" },
    .{ "small", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin" },
    .{ "medium", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin" },
    .{ "large", "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin" },
});

/// Transcription segment with timing information
pub const TranscriptSegment = struct {
    start: f64, // Start time in seconds
    end: f64, // End time in seconds
    text: []const u8,
};

/// Whisper transcription service using whisper.cpp C API
pub const WhisperService = struct {
    allocator: std.mem.Allocator,
    model_path: ?[]const u8 = null,
    ctx: ?*c.whisper_context = null,

    pub fn init(allocator: std.mem.Allocator) WhisperService {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WhisperService) void {
        // Free whisper context if loaded
        if (self.ctx) |ctx| {
            c.whisper_free(ctx);
            self.ctx = null;
        }

        // Free model path
        if (self.model_path) |path| {
            self.allocator.free(path);
            self.model_path = null;
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
        errdefer self.allocator.free(model_path);

        // Check if model file exists
        const file = std.fs.openFileAbsolute(model_path, .{}) catch |err| {
            self.allocator.free(model_path);
            return err;
        };
        file.close();

        // Free previous model if loaded
        if (self.ctx) |ctx| {
            c.whisper_free(ctx);
        }
        if (self.model_path) |path| {
            self.allocator.free(path);
        }

        // Load model with whisper.cpp C API
        const model_path_z = try self.allocator.dupeZ(u8, model_path);
        defer self.allocator.free(model_path_z);

        // Initialize with default context parameters
        const ctx_params = c.whisper_context_default_params();
        const ctx = c.whisper_init_from_file_with_params(model_path_z.ptr, ctx_params);

        if (ctx == null) {
            self.allocator.free(model_path);
            return error.WhisperInitFailed;
        }

        self.ctx = ctx;
        self.model_path = model_path;
        utils.log("Loaded model: {s}", .{model_name});
    }

    /// Transcribe an audio file (WAV format, 16kHz mono PCM)
    pub fn transcribe(self: *WhisperService, audio_path: []const u8) ![]const u8 {
        if (self.ctx == null) {
            return error.ModelNotLoaded;
        }

        const ctx = self.ctx.?;

        // Read audio file
        const audio_data = try self.readAudioFile(audio_path);
        defer self.allocator.free(audio_data);

        // Setup whisper parameters
        const params = c.whisper_full_default_params(c.WHISPER_SAMPLING_GREEDY);

        // Run transcription
        const result = c.whisper_full(
            ctx,
            params,
            audio_data.ptr,
            @as(c_int, @intCast(audio_data.len)),
        );

        if (result != 0) {
            return error.TranscriptionFailed;
        }

        // Get number of segments
        const n_segments = c.whisper_full_n_segments(ctx);
        if (n_segments <= 0) {
            return try self.allocator.dupe(u8, "");
        }

        // Calculate total length first
        var total_len: usize = 0;
        var i: c_int = 0;
        while (i < n_segments) : (i += 1) {
            const segment_text = c.whisper_full_get_segment_text(ctx, i);
            if (segment_text != null) {
                total_len += std.mem.len(segment_text);
            }
        }

        // Allocate buffer and concatenate
        const text_result = try self.allocator.alloc(u8, total_len);
        var pos: usize = 0;
        i = 0;
        while (i < n_segments) : (i += 1) {
            const segment_text = c.whisper_full_get_segment_text(ctx, i);
            if (segment_text != null) {
                const text_slice = std.mem.span(segment_text);
                @memcpy(text_result[pos..][0..text_slice.len], text_slice);
                pos += text_slice.len;
            }
        }

        return text_result;
    }

    /// Get transcription segments with timing information
    pub fn getSegments(self: *WhisperService) ![]TranscriptSegment {
        if (self.ctx == null) {
            return error.ModelNotLoaded;
        }

        const ctx = self.ctx.?;
        const n_segments = c.whisper_full_n_segments(ctx);
        if (n_segments <= 0) {
            return &[_]TranscriptSegment{};
        }

        var segments = std.ArrayList(TranscriptSegment).init(self.allocator);
        errdefer segments.deinit();

        var i: c_int = 0;
        while (i < n_segments) : (i += 1) {
            const t0 = c.whisper_full_get_segment_t0(ctx, i);
            const t1 = c.whisper_full_get_segment_t1(ctx, i);
            const text_ptr = c.whisper_full_get_segment_text(ctx, i);

            if (text_ptr != null) {
                const text_slice = std.mem.span(text_ptr);
                const text_copy = try self.allocator.dupe(u8, text_slice);

                try segments.append(.{
                    .start = @as(f64, @floatFromInt(t0)) / 100.0, // Convert to seconds
                    .end = @as(f64, @floatFromInt(t1)) / 100.0,
                    .text = text_copy,
                });
            }
        }

        return try segments.toOwnedSlice();
    }

    /// Read audio file and convert to float PCM samples
    fn readAudioFile(self: *WhisperService, audio_path: []const u8) ![]f32 {
        // For now, this is a placeholder. In a real implementation,
        // you would need to:
        // 1. Read the WAV file header
        // 2. Verify it's 16kHz mono PCM
        // 3. Convert int16 samples to float32 normalized to [-1, 1]

        const file = try std.fs.cwd().openFile(audio_path, .{});
        defer file.close();

        // Read file size
        const file_size = try file.getEndPos();

        // Skip WAV header (44 bytes for standard PCM WAV)
        try file.seekTo(44);

        const data_size = file_size - 44;
        const n_samples = data_size / 2; // 16-bit samples

        // Read int16 samples
        const int16_data = try self.allocator.alloc(i16, n_samples);
        defer self.allocator.free(int16_data);

        const buffer = std.mem.sliceAsBytes(int16_data);
        var bytes_read: usize = 0;
        while (bytes_read < buffer.len) {
            const n = try file.read(buffer[bytes_read..]);
            if (n == 0) return error.UnexpectedEndOfFile;
            bytes_read += n;
        }

        // Convert to float32
        const float_data = try self.allocator.alloc(f32, n_samples);
        for (int16_data, 0..) |sample, idx| {
            float_data[idx] = @as(f32, @floatFromInt(sample)) / 32768.0;
        }

        return float_data;
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

        const model_filename = try std.fmt.allocPrint(
            self.allocator,
            "{s}/ggml-{s}.bin",
            .{ models_dir, model_name },
        );
        defer self.allocator.free(model_filename);

        // Check if already exists
        if (std.fs.openFileAbsolute(model_filename, .{})) |file| {
            file.close();
            utils.log("Model {s} already exists", .{model_name});
            return;
        } else |_| {
            // File doesn't exist, proceed with download
        }

        const url = ModelUrls.get(model_name) orelse return error.UnknownModel;

        utils.log("Downloading model {s} from {s}", .{ model_name, url });

        // Download model using std.http.Client
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        const uri = try std.Uri.parse(url);
        var req = try client.open(.GET, uri, .{ .server_header_buffer = try self.allocator.alloc(u8, 16384) });
        defer {
            req.deinit();
            self.allocator.free(req.server_header_buffer.?);
        }

        try req.send();
        try req.finish();
        try req.wait();

        // Create output file
        const file = try std.fs.createFileAbsolute(model_filename, .{});
        defer file.close();

        // Read and write in chunks
        var buffer: [8192]u8 = undefined;
        var total_bytes: usize = 0;

        while (true) {
            const bytes_read = try req.readAll(&buffer);
            if (bytes_read == 0) break;

            try file.writeAll(buffer[0..bytes_read]);
            total_bytes += bytes_read;

            if (total_bytes % (1024 * 1024) == 0) {
                utils.log("Downloaded {d} MB", .{total_bytes / (1024 * 1024)});
            }
        }

        utils.log("Model {s} downloaded successfully ({d} bytes)", .{ model_name, total_bytes });
    }

    /// Free segments allocated by getSegments
    pub fn freeSegments(self: *WhisperService, segments: []TranscriptSegment) void {
        for (segments) |seg| {
            self.allocator.free(seg.text);
        }
        self.allocator.free(segments);
    }
};

test "whisper service initialization" {
    const allocator = std.testing.allocator;
    var service = WhisperService.init(allocator);
    defer service.deinit();

    try std.testing.expect(service.model_path == null);
    try std.testing.expect(service.ctx == null);
}

test "whisper model path construction" {
    // Test model name mapping
    try std.testing.expect(ModelUrls.get("base") != null);
    try std.testing.expect(ModelUrls.get("tiny") != null);
    try std.testing.expect(ModelUrls.get("invalid") == null);
}
