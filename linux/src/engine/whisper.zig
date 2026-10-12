const std = @import("std");
const utils = @import("core").utils;
const vocabulary = @import("core").vocabulary;
const wav = @import("core").wav;

// C FFI bindings for whisper.cpp
const c = @import("c_whisper");

/// Hugging Face models are tied to this revision and checked before use.
pub const model_revision = "5359861c739e955e79d9a303bcbc70fb988958b1";
const ModelInfo = struct { filename: []const u8, size: u64, sha256: []const u8 };
const ModelCatalog = std.StaticStringMap(ModelInfo).initComptime(.{
    .{ "tiny", @as(ModelInfo, .{ .filename = "ggml-tiny.bin", .size = 77_691_713, .sha256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21" }) },
    .{ "base", @as(ModelInfo, .{ .filename = "ggml-base.bin", .size = 147_951_465, .sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe" }) },
    .{ "small", @as(ModelInfo, .{ .filename = "ggml-small.bin", .size = 487_601_967, .sha256 = "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b" }) },
    .{ "medium", @as(ModelInfo, .{ .filename = "ggml-medium.bin", .size = 1_533_763_059, .sha256 = "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208" }) },
    .{ "large", @as(ModelInfo, .{ .filename = "ggml-large-v3.bin", .size = 3_095_033_483, .sha256 = "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2" }) },
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
    /// ISO-639-1 code, or "auto" for detection.
    language: [8:0]u8 = "en\x00\x00\x00\x00\x00\x00".*,
    threads: u8 = 4,

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

    /// Apply the transcription language ("auto" detects) and CPU threads.
    pub fn configure(self: *WhisperService, language: []const u8, threads: u8) void {
        const lang = std.mem.trim(u8, language, &std.ascii.whitespace);
        const chosen = if (lang.len == 0 or lang.len >= self.language.len) "auto" else lang;
        @memset(&self.language, 0);
        @memcpy(self.language[0..chosen.len], chosen);
        self.threads = std.math.clamp(threads, 1, 64);
    }

    /// Load a whisper model from disk
    pub fn loadModel(self: *WhisperService, model_name: []const u8) !void {
        const model = ModelCatalog.get(model_name) orelse return error.UnknownModel;
        try self.downloadModel(model_name);

        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);

        const model_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/models/{s}",
            .{ data_dir, model.filename },
        );
        errdefer self.allocator.free(model_path);

        // Check if model file exists
        const file_io = utils.io();
        const file = std.Io.Dir.openFileAbsolute(file_io, model_path, .{}) catch |err| {
            self.allocator.free(model_path);
            return err;
        };
        file.close(file_io);

        // Free previous model if loaded (cleared so a failed reload never
        // leaves dangling pointers behind)
        if (self.ctx) |ctx| {
            c.whisper_free(ctx);
            self.ctx = null;
        }
        if (self.model_path) |path| {
            self.allocator.free(path);
            self.model_path = null;
        }

        // Load model with whisper.cpp C API
        const model_path_z = try utils.dupeZ(self.allocator, model_path);
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
    pub fn transcribe(self: *WhisperService, audio_path: []const u8, vocabulary_prompt: []const u8) ![]const u8 {
        if (self.ctx == null) {
            return error.ModelNotLoaded;
        }

        const ctx = self.ctx.?;

        // Read audio file
        const audio_data = try self.readAudioFile(audio_path);
        defer self.allocator.free(audio_data);

        // Setup whisper parameters
        var params = c.whisper_full_default_params(c.WHISPER_SAMPLING_GREEDY);
        params.language = &self.language;
        params.detect_language = false;
        params.n_threads = self.threads;
        params.print_progress = false;
        const normalized_vocabulary = try vocabulary.normalizePrompt(self.allocator, vocabulary_prompt);
        defer self.allocator.free(normalized_vocabulary);
        const prompt_z = if (normalized_vocabulary.len > 0) try utils.dupeZ(self.allocator, normalized_vocabulary) else null;
        defer if (prompt_z) |prompt| self.allocator.free(prompt);
        if (prompt_z) |prompt| {
            params.initial_prompt = prompt.ptr;
            params.carry_initial_prompt = true;
        }

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

        var segments = std.ArrayList(TranscriptSegment).empty;
        errdefer segments.deinit(self.allocator);

        var i: c_int = 0;
        while (i < n_segments) : (i += 1) {
            const t0 = c.whisper_full_get_segment_t0(ctx, i);
            const t1 = c.whisper_full_get_segment_t1(ctx, i);
            const text_ptr = c.whisper_full_get_segment_text(ctx, i);

            if (text_ptr != null) {
                const text_slice = std.mem.span(text_ptr);
                const text_copy = try self.allocator.dupe(u8, text_slice);

                try segments.append(self.allocator, .{
                    .start = @as(f64, @floatFromInt(t0)) / 100.0, // Convert to seconds
                    .end = @as(f64, @floatFromInt(t1)) / 100.0,
                    .text = text_copy,
                });
            }
        }

        return try segments.toOwnedSlice(self.allocator);
    }

    /// Read a WAV file as 16 kHz mono f32, whatever its layout, channel
    /// count or sample rate (16-bit PCM only).
    fn readAudioFile(self: *WhisperService, audio_path: []const u8) ![]f32 {
        const max_bytes = 1024 * 1024 * 1024; // ~9h of 16 kHz mono
        const bytes = try std.Io.Dir.cwd().readFileAlloc(utils.io(), audio_path, self.allocator, .limited(max_bytes));
        defer self.allocator.free(bytes);
        return wav.toMonoF32(self.allocator, try wav.parse(bytes), c.WHISPER_SAMPLE_RATE);
    }

    /// Download a model if it doesn't exist
    pub fn downloadModel(self: *WhisperService, model_name: []const u8) !void {
        const model = ModelCatalog.get(model_name) orelse return error.UnknownModel;
        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);

        const models_dir = try std.fmt.allocPrint(
            self.allocator,
            "{s}/models",
            .{data_dir},
        );
        defer self.allocator.free(models_dir);

        try std.Io.Dir.cwd().createDirPath(utils.io(), models_dir);

        const destination = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}",
            .{ models_dir, model.filename },
        );
        defer self.allocator.free(destination);

        if (try isVerified(destination, model)) {
            utils.log("Verified Whisper model {s} already exists", .{model_name});
            return;
        }
        if (utils.getEnv("TALKIES_OFFLINE_ACCEPTANCE") != null) return error.OfflineModelUnavailable;

        const partial = try std.fmt.allocPrint(self.allocator, "{s}.partial", .{destination});
        defer self.allocator.free(partial);
        errdefer std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch {};
        std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch {};
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/{s}/{s}?download=true",
            .{ model_revision, model.filename },
        );
        defer self.allocator.free(url);

        utils.log("Downloading model {s} from {s}", .{ model_name, url });

        const argv = &[_][]const u8{
            "curl",
            "--fail",
            "--location",
            "--retry",
            "3",
            "-o",
            partial,
            "--progress-bar",
            url,
        };

        var child = try std.process.spawn(utils.io(), .{ .argv = argv });
        const term = try child.wait(utils.io());
        if (!term.success()) return error.DownloadFailed;
        if (!try isVerified(partial, model)) return error.ModelIntegrityCheckFailed;

        std.Io.Dir.deleteFileAbsolute(utils.io(), destination) catch |err| {
            if (err != error.FileNotFound) return err;
        };
        try std.Io.Dir.renameAbsolute(partial, destination, utils.io());
        utils.log("Model {s} downloaded successfully", .{model_name});
    }

    /// Free segments allocated by getSegments
    pub fn freeSegments(self: *WhisperService, segments: []TranscriptSegment) void {
        for (segments) |seg| {
            self.allocator.free(seg.text);
        }
        self.allocator.free(segments);
    }
};

/// Bytes still to download for `model_name` (0 when a complete file is
/// present). A size check only: cheap enough for `talkies doctor`; loading
/// still verifies the SHA-256.
pub fn missingModelBytes(allocator: std.mem.Allocator, model_name: []const u8) !u64 {
    const model = ModelCatalog.get(model_name) orelse return error.UnknownModel;
    const data_dir = try utils.getDataDir(allocator);
    defer allocator.free(data_dir);
    const path = try std.fmt.allocPrint(allocator, "{s}/models/{s}", .{ data_dir, model.filename });
    defer allocator.free(path);
    const file = std.Io.Dir.openFileAbsolute(utils.io(), path, .{}) catch |err| switch (err) {
        error.FileNotFound => return model.size,
        else => return err,
    };
    defer file.close(utils.io());
    return if ((try file.stat(utils.io())).size == model.size) 0 else model.size;
}

fn isVerified(path: []const u8, model: ModelInfo) !bool {
    const file = std.Io.Dir.openFileAbsolute(utils.io(), path, .{}) catch return false;
    defer file.close(utils.io());
    if ((try file.stat(utils.io())).size != model.size) return false;

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [1024 * 1024]u8 = undefined;
    while (true) {
        const count = file.readStreaming(utils.io(), &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (count == 0) break;
        hasher.update(buffer[0..count]);
    }

    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    const hex_chars = "0123456789abcdef";
    var hex: [64]u8 = undefined;
    for (digest, 0..) |byte, index| {
        hex[index * 2] = hex_chars[byte >> 4];
        hex[index * 2 + 1] = hex_chars[byte & 0x0f];
    }
    return std.mem.eql(u8, &hex, model.sha256);
}

test "whisper service initialization" {
    const allocator = std.testing.allocator;
    var service = WhisperService.init(allocator);
    defer service.deinit();

    try std.testing.expect(service.model_path == null);
    try std.testing.expect(service.ctx == null);
}

test "whisper model path construction" {
    const base = ModelCatalog.get("base") orelse return error.MissingBaseModel;
    const tiny = ModelCatalog.get("tiny") orelse return error.MissingTinyModel;
    const large = ModelCatalog.get("large") orelse return error.MissingLargeModel;
    try std.testing.expectEqualStrings("ggml-base.bin", base.filename);
    try std.testing.expectEqualStrings("ggml-tiny.bin", tiny.filename);
    try std.testing.expectEqualStrings("ggml-large-v3.bin", large.filename);
    try std.testing.expect(ModelCatalog.get("invalid") == null);
    try std.testing.expectEqual(@as(u64, 77_691_713), tiny.size);
    try std.testing.expectEqualStrings("be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21", tiny.sha256);
}

test "pinned Whisper tiny recognizes the shared JFK sample offline on CPU" {
    if (utils.getEnv("TALKIES_TEST_WHISPER") == null) return error.SkipZigTest;
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);

    var service = WhisperService.init(std.testing.allocator);
    defer service.deinit();
    try service.loadModel("tiny");
    const text = try service.transcribe("../tests/fixtures/jfk.wav", "");
    defer std.testing.allocator.free(text);
    const lower = try std.ascii.allocLowerString(std.testing.allocator, text);
    defer std.testing.allocator.free(lower);
    try std.testing.expect(std.mem.indexOf(u8, lower, "country") != null);
}
