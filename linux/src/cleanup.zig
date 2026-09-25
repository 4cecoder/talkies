const std = @import("std");
const utils = @import("utils.zig");
const c_runtime = @import("c_s1_runtime");

/// S1-mini is a transcript post-processor. Its pinned weights and prompt are
/// shared with the macOS and Windows implementations.
pub const model_repository = "superwhisper/s1-mini-GGUF";
pub const model_revision = "34add00a48a2e5d24e5a4ee5405a99620a3a240c";
pub const model_filename = "s1-mini-q4_k_m.gguf";
pub const model_size: u64 = 484_219_808;
pub const model_sha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
const system_prompt = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.";

pub const Options = struct {
    style: Style = .semi_formal,
    structure: Structure = .prose,
    context: Context = .general,
};

pub const Style = enum { casual, semi_casual, semi_formal, formal };
pub const Structure = enum { prose, lists };
pub const Context = enum { general, email };

fn styleName(style: Style) []const u8 {
    return switch (style) {
        .casual => "casual",
        .semi_casual => "semi-casual",
        .semi_formal => "semi-formal",
        .formal => "formal",
    };
}

/// Build the Qwen3 chat prefix expected by S1-mini. The transcript remains
/// plain text; inference callers must not send it to a remote service.
pub fn renderPrompt(allocator: std.mem.Allocator, transcript: []const u8, options: Options) ![]u8 {
    const trimmed = std.mem.trim(u8, transcript, " \t\r\n");
    return std.fmt.allocPrint(
        allocator,
        "<|im_start|>system\n{s}<|im_end|>\n<|im_start|>user\n[Styling: {s}] [Structure: {s}] [Context: {s}]\n{s}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
        .{ system_prompt, styleName(options.style), @tagName(options.structure), @tagName(options.context), trimmed },
    );
}

/// Keep the ASR transcript if the model returns an empty or whitespace-only
/// response. Caller owns the returned allocation in either case.
pub fn cleanedOrOriginal(allocator: std.mem.Allocator, original: []const u8, cleaned: []const u8) ![]u8 {
    const candidate = std.mem.trim(u8, cleaned, " \t\r\n");
    if (candidate.len == 0) return allocator.dupe(u8, original);
    return allocator.dupe(u8, candidate);
}

/// Downloads the pinned model once, verifies its size and SHA-256, and keeps
/// the required upstream license notices beside the weights.
pub const ModelStore = struct {
    allocator: std.mem.Allocator,

    pub fn ensureAvailable(self: ModelStore) ![]u8 {
        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);
        const model_dir = try std.fmt.allocPrint(self.allocator, "{s}/models/s1-mini-{s}", .{ data_dir, model_revision });
        defer self.allocator.free(model_dir);
        try std.Io.Dir.cwd().createDirPath(utils.io(), model_dir);

        const model_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ model_dir, model_filename });
        errdefer self.allocator.free(model_path);
        if (!try isVerified(model_path)) {
            try self.downloadVerified(model_dir, model_filename, model_size, model_sha256);
        }
        try self.downloadVerified(model_dir, "LICENSE", null, null);
        try self.downloadVerified(model_dir, "NOTICE", null, null);
        return model_path;
    }

    fn downloadVerified(self: ModelStore, directory: []const u8, name: []const u8, size: ?u64, expected_hash: ?[]const u8) !void {
        const destination = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ directory, name });
        defer self.allocator.free(destination);
        if (size != null and expected_hash != null and try isVerified(destination)) return;
        if (size == null and fileExists(destination)) return;
        if (utils.getEnv("TALKIES_OFFLINE_ACCEPTANCE") != null) return error.OfflineModelUnavailable;

        const partial = try std.fmt.allocPrint(self.allocator, "{s}.partial", .{destination});
        defer self.allocator.free(partial);
        errdefer std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch {};
        std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch {};
        const url = try std.fmt.allocPrint(
            self.allocator,
            "https://huggingface.co/{s}/resolve/{s}/{s}?download=true",
            .{ model_repository, model_revision, name },
        );
        defer self.allocator.free(url);
        const argv = &[_][]const u8{ "curl", "--fail", "--location", "--retry", "3", "--progress-bar", "--output", partial, url };
        var child = try std.process.spawn(utils.io(), .{ .argv = argv });
        const term = try child.wait(utils.io());
        if (!term.success()) return error.ModelDownloadFailed;

        if (size) |expected_size| {
            const verified = try isVerifiedWith(partial, partial, expected_size, expected_hash.?);
            if (!verified) return error.ModelIntegrityCheckFailed;
        } else {
            const file = try std.Io.Dir.openFileAbsolute(utils.io(), partial, .{});
            defer file.close(utils.io());
            if ((try file.stat(utils.io())).size == 0) return error.EmptyModelLicenseFile;
        }
        std.Io.Dir.deleteFileAbsolute(utils.io(), destination) catch |err| {
            if (err != error.FileNotFound) return err;
        };
        try std.Io.Dir.renameAbsolute(partial, destination, utils.io());
    }
};

fn fileExists(path: []const u8) bool {
    const file = std.Io.Dir.openFileAbsolute(utils.io(), path, .{}) catch return false;
    const stat = file.stat(utils.io()) catch {
        file.close(utils.io());
        return false;
    };
    file.close(utils.io());
    return stat.size > 0;
}

fn isVerified(path: []const u8) !bool {
    return isVerifiedWith(path, path, model_size, model_sha256);
}

fn isVerifiedWith(stat_path: []const u8, hash_path: []const u8, expected_size: u64, expected_hash: []const u8) !bool {
    const file = std.Io.Dir.openFileAbsolute(utils.io(), stat_path, .{}) catch return false;
    defer file.close(utils.io());
    if ((try file.stat(utils.io())).size != expected_size) return false;

    const hash_file = std.Io.Dir.openFileAbsolute(utils.io(), hash_path, .{}) catch return false;
    defer hash_file.close(utils.io());
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [1024 * 1024]u8 = undefined;
    while (true) {
        const count = hash_file.readStreaming(utils.io(), &.{&buffer}) catch |err| switch (err) {
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
    return std.mem.eql(u8, &hex, expected_hash);
}

/// Lazily loads S1-mini on CPU and retains one model/context for later clips.
pub const Cleaner = struct {
    allocator: std.mem.Allocator,
    threads: u8 = 4,
    runtime: ?*c_runtime.talkies_s1_runtime = null,

    pub fn deinit(self: *Cleaner) void {
        if (self.runtime) |runtime| c_runtime.talkies_s1_runtime_destroy(runtime);
        self.runtime = null;
    }

    pub fn clean(self: *Cleaner, transcript: []const u8, options: Options) ![]u8 {
        const trimmed = std.mem.trim(u8, transcript, " \t\r\n");
        if (trimmed.len == 0) return self.allocator.dupe(u8, transcript);
        const prompt = try renderPrompt(self.allocator, trimmed, options);
        defer self.allocator.free(prompt);
        if (self.runtime == null) {
            const model_path = try (ModelStore{ .allocator = self.allocator }).ensureAvailable();
            defer self.allocator.free(model_path);
            const z_model_path = try utils.dupeZ(self.allocator, model_path);
            defer self.allocator.free(z_model_path);
            self.runtime = c_runtime.talkies_s1_runtime_create(z_model_path, self.threads) orelse return error.ModelLoadFailed;
        }
        const z_prompt = try utils.dupeZ(self.allocator, prompt);
        defer self.allocator.free(z_prompt);
        const output = try self.allocator.alloc(u8, 32 * 1024);
        defer self.allocator.free(output);
        const result = c_runtime.talkies_s1_runtime_clean(self.runtime.?, z_prompt, output.ptr, output.len);
        if (result != 0) return error.InferenceFailed;
        return cleanedOrOriginal(self.allocator, transcript, std.mem.sliceTo(output, 0));
    }
};

test "prompt matches the shared S1-mini format" {
    const prompt = try renderPrompt(std.testing.allocator, "  send the email tomorrow  ", .{});
    defer std.testing.allocator.free(prompt);
    try std.testing.expectEqualStrings(
        "<|im_start|>system\nYou are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text.<|im_end|>\n<|im_start|>user\n[Styling: semi-formal] [Structure: prose] [Context: general]\nsend the email tomorrow<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
        prompt,
    );
}

test "all style and structure options render as model control values" {
    const prompt = try renderPrompt(std.testing.allocator, "hello", .{
        .style = .semi_casual,
        .structure = .lists,
        .context = .email,
    });
    defer std.testing.allocator.free(prompt);
    try std.testing.expect(std.mem.indexOf(u8, prompt, "[Styling: semi-casual] [Structure: lists] [Context: email]") != null);
}

test "blank model output falls back to the original transcript" {
    const result = try cleanedOrOriginal(std.testing.allocator, " raw ASR ", " \n\t ");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(" raw ASR ", result);
}

test "pinned S1-mini model runs a cleanup on CPU" {
    if (utils.getEnv("TALKIES_TEST_S1_MINI") == null) return error.SkipZigTest;
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);
    var cleaner = Cleaner{ .allocator = std.testing.allocator };
    defer cleaner.deinit();
    const cleaned = try cleaner.clean("um i think we should uh send the email tomorrow", .{});
    defer std.testing.allocator.free(cleaned);
    const lowercase = try std.ascii.allocLowerString(std.testing.allocator, cleaned);
    defer std.testing.allocator.free(lowercase);
    try std.testing.expect(std.mem.indexOf(u8, lowercase, "send the email tomorrow") != null);
    try std.testing.expect(std.mem.indexOf(u8, lowercase, "um") == null);
    try std.testing.expect(std.mem.indexOf(u8, lowercase, " uh ") == null);

    const follow_up = try cleaner.clean("um please schedule the review for Wednesday no Friday", .{});
    defer std.testing.allocator.free(follow_up);
    const lowercase_follow_up = try std.ascii.allocLowerString(std.testing.allocator, follow_up);
    defer std.testing.allocator.free(lowercase_follow_up);
    try std.testing.expect(std.mem.indexOf(u8, lowercase_follow_up, "friday") != null);
    try std.testing.expect(std.mem.indexOf(u8, lowercase_follow_up, "wednesday") == null);
    try std.testing.expect(!std.mem.startsWith(u8, lowercase_follow_up, "um "));
}
