//! Phonon-2 recognizer on CrispASR (see src/native/crispasr_runtime.c).
//! Loading verifies the pinned model and never downloads; the CrispASR
//! runtime is bundled under `lib/crispasr/` next to the Talkies binary.

const std = @import("std");
const utils = @import("core").utils;
const wav = @import("core").wav;
const model = @import("phonon_model.zig");
const c = @import("c_crispasr_runtime");

pub const PhononService = struct {
    allocator: std.mem.Allocator,
    runtime: ?*c.talkies_crispasr = null,
    threads: u8 = 4,
    /// Last load/transcribe failure, for logs and the status check.
    error_buf: [256]u8 = undefined,
    error_len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) PhononService {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *PhononService) void {
        self.unload();
    }

    pub fn isLoaded(self: *const PhononService) bool {
        return self.runtime != null;
    }

    pub fn lastError(self: *const PhononService) []const u8 {
        return self.error_buf[0..self.error_len];
    }

    pub fn store(self: *const PhononService) model.ModelStore {
        return .{ .allocator = self.allocator, .quiet = true };
    }

    pub fn unload(self: *PhononService) void {
        if (self.runtime) |runtime| {
            c.talkies_crispasr_close(runtime);
            self.runtime = null;
        }
    }

    /// Verify the installed model and open it. No network access.
    pub fn load(self: *PhononService) !void {
        self.unload();
        self.error_len = 0;
        const model_path = self.store().verifiedModelPath() catch |err| {
            self.setError("model: {s}", .{@errorName(err)});
            return err;
        };
        defer self.allocator.free(model_path);

        var dir_buf: [std.fs.max_path_bytes:0]u8 = undefined;
        const runtime_dir = runtimeDir(&dir_buf) orelse {
            self.setError("the CrispASR runtime is not installed (lib/crispasr)", .{});
            return error.PhononRuntimeMissing;
        };

        var err_buf: [256:0]u8 = @splat(0);
        const runtime = c.talkies_crispasr_open(runtime_dir.ptr, model_path.ptr, self.threads, &err_buf, err_buf.len) orelse {
            self.setError("{s}", .{std.mem.sliceTo(&err_buf, 0)});
            return error.PhononLoadFailed;
        };
        self.runtime = runtime;
        utils.log("Loaded Phonon-2 ({s}) with CrispASR from {s}", .{ model.model.name, runtime_dir });
    }

    /// Transcribe a 16-bit PCM WAV as English. Caller owns the text.
    pub fn transcribe(self: *PhononService, audio_path: []const u8) ![]u8 {
        const runtime = self.runtime orelse return error.ModelNotLoaded;
        const max_bytes = 1024 * 1024 * 1024;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(utils.io(), audio_path, self.allocator, .limited(max_bytes));
        defer self.allocator.free(bytes);
        const pcm = try wav.toMonoF32(self.allocator, try wav.parse(bytes), model.sample_rate);
        defer self.allocator.free(pcm);
        if (pcm.len > std.math.maxInt(i32)) return error.AudioTooLong;

        var err_buf: [256:0]u8 = @splat(0);
        const text = c.talkies_crispasr_transcribe(runtime, pcm.ptr, @intCast(pcm.len), "en", &err_buf, err_buf.len) orelse {
            self.setError("{s}", .{std.mem.sliceTo(&err_buf, 0)});
            return error.PhononTranscriptionFailed;
        };
        defer c.talkies_crispasr_free_text(text);
        return self.allocator.dupe(u8, std.mem.span(text));
    }

    fn setError(self: *PhononService, comptime fmt: []const u8, args: anytype) void {
        const written = std.fmt.bufPrint(&self.error_buf, fmt, args) catch self.error_buf[0..];
        self.error_len = written.len;
    }
};

/// `$TALKIES_CRISPASR_DIR`, else `<exe>/lib/crispasr` (installed tree) or
/// `<exe>/../lib/crispasr` (zig-out). Null when none holds libcrispasr.
pub fn runtimeDir(buf: *[std.fs.max_path_bytes:0]u8) ?[:0]const u8 {
    if (utils.getEnv("TALKIES_CRISPASR_DIR")) |dir| {
        return std.fmt.bufPrintSentinel(buf, "{s}", .{dir}, 0) catch null;
    }
    var exe_buf: [std.fs.max_path_bytes]u8 = undefined;
    const rc = std.os.linux.readlink("/proc/self/exe", &exe_buf, exe_buf.len);
    if (std.os.linux.errno(rc) != .SUCCESS) return null;
    const exe_dir = std.fs.path.dirname(exe_buf[0..rc]) orelse return null;
    for ([_][]const u8{ "lib/crispasr", "../lib/crispasr" }) |rel| {
        const dir = std.fmt.bufPrintSentinel(buf, "{s}/{s}", .{ exe_dir, rel }, 0) catch continue;
        var probe_buf: [std.fs.max_path_bytes]u8 = undefined;
        const probe = std.fmt.bufPrint(&probe_buf, "{s}/libcrispasr.so.1", .{dir}) catch continue;
        if (std.Io.Dir.cwd().access(utils.io(), probe, .{})) |_| return dir else |_| {}
    }
    return null;
}

test "phonon service starts unloaded" {
    var service = PhononService.init(std.testing.allocator);
    defer service.deinit();
    try std.testing.expect(!service.isLoaded());
    try std.testing.expectError(error.ModelNotLoaded, service.transcribe("missing.wav"));
}

test "pinned Phonon-2 recognizes the shared JFK sample offline on CPU" {
    if (utils.getEnv("TALKIES_TEST_PHONON") == null) return error.SkipZigTest;
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);

    var service = PhononService.init(std.testing.allocator);
    defer service.deinit();
    service.load() catch |err| {
        std.debug.print("Phonon-2 load failed: {s}\n", .{service.lastError()});
        return err;
    };
    const text = try service.transcribe("../tests/fixtures/jfk.wav");
    defer std.testing.allocator.free(text);
    const lower = try std.ascii.allocLowerString(std.testing.allocator, text);
    defer std.testing.allocator.free(lower);
    try std.testing.expect(std.mem.indexOf(u8, lower, "country") != null);
}
