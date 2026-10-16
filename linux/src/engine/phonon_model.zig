//! Phonon-2 model metadata and its verified on-disk store.
//!
//! Phonon-2 is Fermion Research's compressed NVIDIA Parakeet TDT 0.6B v3
//! (English-only, weights CC-BY-4.0), converted to GGUF for CrispASR. Every
//! file is pinned to one Hugging Face revision and checked for its exact size
//! and SHA-256. Downloads happen only when the user asks for one; loading
//! never touches the network.

const std = @import("std");
const utils = @import("core").utils;

pub const repository = "cstr/phonon2-GGUF";
pub const revision = "3ed3e6ad6e7ce63affffeede37328ff756efaa2f";
pub const sample_rate: u32 = 16_000;

pub const File = struct { name: []const u8, size: u64, sha256: []const u8 };

/// Default quantization: the size/fidelity balance the model card recommends.
pub const model: File = .{
    .name = "phonon2-q8_0.gguf",
    .size = 674_342_560,
    .sha256 = "a8c4a874195b83604ceb5d87c0e9b5ddf641ef1d5ec2d8e1ca2a040d25b2563a",
};
/// CC-BY-4.0 terms and the attribution notice required beside the weights.
pub const license: File = .{
    .name = "LICENSE",
    .size = 18_657,
    .sha256 = "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411",
};
pub const notice: File = .{
    .name = "NOTICE",
    .size = 2_741,
    .sha256 = "00624a5043e7ce74029317b024132ca5286116d6fbf3191d226374bc8273789f",
};
/// Notices first: weights are never installed without their attribution.
pub const files = [_]File{ license, notice, model };

/// Total download size in bytes.
pub fn downloadSize() u64 {
    var total: u64 = 0;
    for (files) |file| total += file.size;
    return total;
}

/// Caller owns the returned URL.
pub fn downloadUrl(allocator: std.mem.Allocator, file: File) ![]u8 {
    return std.fmt.allocPrint(allocator, "https://huggingface.co/{s}/resolve/{s}/{s}?download=true", .{ repository, revision, file.name });
}

pub const ModelStore = struct {
    allocator: std.mem.Allocator,
    /// Suppress curl's progress bar (GUI downloads poll `downloadedBytes`).
    quiet: bool = false,

    /// `$XDG_DATA_HOME/talkies/models/phonon2-<revision>`. Caller owns it.
    pub fn modelDir(self: ModelStore) ![]u8 {
        const data_dir = try utils.getDataDir(self.allocator);
        defer self.allocator.free(data_dir);
        return std.fmt.allocPrint(self.allocator, "{s}/models/phonon2-{s}", .{ data_dir, revision });
    }

    /// Caller owns the returned path.
    pub fn filePath(self: ModelStore, name: []const u8) ![]u8 {
        const dir = try self.modelDir();
        defer self.allocator.free(dir);
        return std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ dir, name });
    }

    /// Cheap readiness check (exact sizes). Loading re-verifies SHA-256.
    pub fn isInstalled(self: ModelStore) bool {
        for (files) |file| {
            const path = self.filePath(file.name) catch return false;
            defer self.allocator.free(path);
            if (fileSize(path) != file.size) return false;
        }
        return true;
    }

    /// Bytes on disk so far, counting completed files and the current partial.
    pub fn downloadedBytes(self: ModelStore) u64 {
        var total: u64 = 0;
        for (files) |file| {
            const path = self.filePath(file.name) catch return total;
            defer self.allocator.free(path);
            const size = fileSize(path) orelse blk: {
                const partial = std.fmt.allocPrint(self.allocator, "{s}.partial", .{path}) catch break :blk null;
                defer self.allocator.free(partial);
                break :blk fileSize(partial);
            };
            total += @min(size orelse 0, file.size);
        }
        return total;
    }

    /// Verify every file and return the model path for loading. Never
    /// downloads. Caller owns the returned path.
    pub fn verifiedModelPath(self: ModelStore) ![:0]u8 {
        for (files) |file| {
            const path = try self.filePath(file.name);
            defer self.allocator.free(path);
            if (fileSize(path) == null) return error.PhononModelNotInstalled;
            if (!try isVerified(path, file)) return error.ModelIntegrityCheckFailed;
        }
        const path = try self.filePath(model.name);
        defer self.allocator.free(path);
        return utils.dupeZ(self.allocator, path);
    }

    /// Explicit download: fetch whatever is missing or corrupt, verifying
    /// each file before it is renamed into place.
    pub fn download(self: ModelStore) !void {
        const dir = try self.modelDir();
        defer self.allocator.free(dir);
        try std.Io.Dir.cwd().createDirPath(utils.io(), dir);
        for (files) |file| try self.downloadVerified(file);
    }

    /// Delete the weights and notices.
    pub fn remove(self: ModelStore) !void {
        const dir = try self.modelDir();
        defer self.allocator.free(dir);
        try std.Io.Dir.cwd().deleteTree(utils.io(), dir);
    }

    fn downloadVerified(self: ModelStore, file: File) !void {
        const destination = try self.filePath(file.name);
        defer self.allocator.free(destination);
        if (try isVerified(destination, file)) return;
        if (utils.getEnv("TALKIES_OFFLINE_ACCEPTANCE") != null) return error.OfflineModelUnavailable;

        const partial = try std.fmt.allocPrint(self.allocator, "{s}.partial", .{destination});
        defer self.allocator.free(partial);
        errdefer std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch |err| utils.logDebug("remove partial: {}", .{err});
        std.Io.Dir.deleteFileAbsolute(utils.io(), partial) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
        const url = try downloadUrl(self.allocator, file);
        defer self.allocator.free(url);
        utils.log("Downloading Phonon-2 {s} from {s}", .{ file.name, url });

        const progress: []const u8 = if (self.quiet) "--silent" else "--progress-bar";
        const argv = &[_][]const u8{ "curl", "--fail", "--location", "--retry", "3", "--show-error", progress, "--output", partial, url };
        var child = try std.process.spawn(utils.io(), .{ .argv = argv });
        const term = try child.wait(utils.io());
        if (!term.success()) return error.ModelDownloadFailed;
        if (!try isVerified(partial, file)) return error.ModelIntegrityCheckFailed;

        std.Io.Dir.deleteFileAbsolute(utils.io(), destination) catch |err| {
            if (err != error.FileNotFound) return err;
        };
        try std.Io.Dir.renameAbsolute(partial, destination, utils.io());
    }
};

fn fileSize(path: []const u8) ?u64 {
    const file = std.Io.Dir.openFileAbsolute(utils.io(), path, .{}) catch return null;
    defer file.close(utils.io());
    const stat = file.stat(utils.io()) catch return null;
    return stat.size;
}

/// Exact size, then SHA-256. False when the file is missing.
pub fn isVerified(path: []const u8, expected: File) !bool {
    const file = std.Io.Dir.openFileAbsolute(utils.io(), path, .{}) catch return false;
    defer file.close(utils.io());
    if ((try file.stat(utils.io())).size != expected.size) return false;

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
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.mem.eql(u8, &hex, expected.sha256);
}

test "Phonon-2 metadata is pinned to the reviewed revision and hashes" {
    try std.testing.expectEqualStrings("cstr/phonon2-GGUF", repository);
    try std.testing.expectEqualStrings("3ed3e6ad6e7ce63affffeede37328ff756efaa2f", revision);
    try std.testing.expectEqualStrings("phonon2-q8_0.gguf", model.name);
    try std.testing.expectEqual(@as(u64, 674_342_560), model.size);
    try std.testing.expectEqualStrings("a8c4a874195b83604ceb5d87c0e9b5ddf641ef1d5ec2d8e1ca2a040d25b2563a", model.sha256);
    try std.testing.expectEqual(@as(u64, 674_342_560 + 18_657 + 2_741), downloadSize());
    for (files) |file| {
        try std.testing.expectEqual(@as(usize, 64), file.sha256.len);
        for (file.sha256) |ch| try std.testing.expect(std.ascii.isDigit(ch) or (ch >= 'a' and ch <= 'f'));
    }
    // License files come before the weights.
    try std.testing.expectEqualStrings("phonon2-q8_0.gguf", files[files.len - 1].name);
}

test "Phonon-2 download URLs use the pinned revision, never a branch" {
    const url = try downloadUrl(std.testing.allocator, model);
    defer std.testing.allocator.free(url);
    try std.testing.expectEqualStrings(
        "https://huggingface.co/cstr/phonon2-GGUF/resolve/3ed3e6ad6e7ce63affffeede37328ff756efaa2f/phonon2-q8_0.gguf?download=true",
        url,
    );
    const notice_url = try downloadUrl(std.testing.allocator, notice);
    defer std.testing.allocator.free(notice_url);
    try std.testing.expect(std.mem.indexOf(u8, notice_url, "/main/") == null);
    try std.testing.expect(std.mem.endsWith(u8, notice_url, "/NOTICE?download=true"));
}

test "verification rejects wrong size and wrong hash, accepts the exact file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(utils.io(), .{ .sub_path = "sample", .data = "abc" });
    const dir_path = try tmp.dir.realPathFileAlloc(utils.io(), ".", std.testing.allocator);
    defer std.testing.allocator.free(dir_path);
    const path = try std.fmt.allocPrint(std.testing.allocator, "{s}/sample", .{dir_path});
    defer std.testing.allocator.free(path);

    const abc_sha256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
    try std.testing.expect(try isVerified(path, .{ .name = "sample", .size = 3, .sha256 = abc_sha256 }));
    try std.testing.expect(!try isVerified(path, .{ .name = "sample", .size = 4, .sha256 = abc_sha256 }));
    try std.testing.expect(!try isVerified(path, .{ .name = "sample", .size = 3, .sha256 = model.sha256 }));
    const missing = try std.fmt.allocPrint(std.testing.allocator, "{s}/missing", .{dir_path});
    defer std.testing.allocator.free(missing);
    try std.testing.expect(!try isVerified(missing, model));
}
