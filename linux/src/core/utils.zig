const std = @import("std");

/// Log a message to stderr with timestamp
pub fn log(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[talkies] " ++ fmt ++ "\n", args);
}

/// Log an error message
pub fn logError(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("[ERROR] " ++ fmt ++ "\n", args);
}

/// Log a debug message (only in debug builds)
pub fn logDebug(comptime fmt: []const u8, args: anytype) void {
    if (@import("builtin").mode == .debug) {
        std.debug.print("[DEBUG] " ++ fmt ++ "\n", args);
    }
}

/// Read a process environment value using libc's current environment.
pub fn getEnv(name: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name) orelse return null;
    return std.mem.span(value);
}

pub fn io() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// Configure the process-wide single-threaded I/O implementation. Zig's
/// static default uses Allocator.failing, which breaks process spawning for
/// curl-based model downloads unless the application supplies an allocator.
pub fn setIoAllocator(allocator: std.mem.Allocator) void {
    std.Io.Threaded.global_single_threaded.allocator = allocator;
}

pub fn sleepNanoseconds(nanoseconds: u64) void {
    io().sleep(.fromNanoseconds(@intCast(nanoseconds)), .awake) catch {};
}

pub fn monotonicMilliseconds() i64 {
    return std.Io.Timestamp.now(io(), .awake).toMilliseconds();
}

pub fn monotonicTimestamp() std.Io.Timestamp {
    return std.Io.Timestamp.now(io(), .awake);
}

pub fn realtimeSeconds() i64 {
    return std.Io.Timestamp.now(io(), .real).toSeconds();
}

pub fn dupeZ(allocator: std.mem.Allocator, value: []const u8) ![:0]u8 {
    return std.mem.concatWithSentinel(allocator, u8, &.{value}, 0);
}

/// Get XDG config directory (~/.config/talkies)
pub fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
    const home = getEnv("HOME") orelse return error.NoHomeDir;
    const xdg_config = getEnv("XDG_CONFIG_HOME");

    if (xdg_config) |config_base| {
        return std.fmt.allocPrint(allocator, "{s}/talkies", .{config_base});
    } else {
        return std.fmt.allocPrint(allocator, "{s}/.config/talkies", .{home});
    }
}

/// Get XDG data directory (~/.local/share/talkies)
pub fn getDataDir(allocator: std.mem.Allocator) ![]const u8 {
    const home = getEnv("HOME") orelse return error.NoHomeDir;
    const xdg_data = getEnv("XDG_DATA_HOME");

    if (xdg_data) |data_base| {
        return std.fmt.allocPrint(allocator, "{s}/talkies", .{data_base});
    } else {
        return std.fmt.allocPrint(allocator, "{s}/.local/share/talkies", .{home});
    }
}

/// Path for a transient per-user file (recordings) inside a private 0700
/// directory: $XDG_RUNTIME_DIR/talkies, else ~/.local/share/talkies/run.
/// Never /tmp, where other users could read the audio or pre-plant symlinks.
/// Caller owns the returned path.
pub fn privateRuntimePath(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const base = if (getEnv("XDG_RUNTIME_DIR")) |runtime|
        try std.fmt.allocPrint(allocator, "{s}/talkies", .{runtime})
    else blk: {
        const data_dir = try getDataDir(allocator);
        defer allocator.free(data_dir);
        try ensureDir(data_dir);
        break :blk try std.fmt.allocPrint(allocator, "{s}/run", .{data_dir});
    };
    defer allocator.free(base);

    std.Io.Dir.createDirAbsolute(io(), base, .fromMode(0o700)) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    // Tighten an existing directory created by an older version.
    const base_z = try dupeZ(allocator, base);
    defer allocator.free(base_z);
    if (std.c.chmod(base_z.ptr, 0o700) != 0) return error.AccessDenied;
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, name });
}

/// Ensure an absolute directory exists, creating missing parents (mkdir -p):
/// on a fresh account even ~/.config or ~/.local/share may not exist yet.
pub fn ensureDir(path: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), path);
}

test "ensureDir creates missing parents and tolerates existing dirs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const base_len = try tmp.dir.realPath(std.testing.io, &buf);
    const nested = try std.fmt.allocPrint(std.testing.allocator, "{s}/a/b/c", .{buf[0..base_len]});
    defer std.testing.allocator.free(nested);
    try ensureDir(nested);
    try ensureDir(nested);
    var dir = try std.Io.Dir.openDirAbsolute(std.testing.io, nested, .{});
    dir.close(std.testing.io);
}

/// Run a command and capture its stdout. Fails if it exits unsuccessfully.
/// Caller owns returned memory.
pub fn runCapture(allocator: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var child = try std.process.spawn(io(), .{ .argv = argv, .stdin = .ignore, .stdout = .pipe, .stderr = .ignore });
    const stdout = child.stdout orelse return error.NoStdout;

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var buffer: [4096]u8 = undefined;
    while (true) {
        const n = stdout.readStreaming(io(), &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (n == 0) break;
        try output.appendSlice(allocator, buffer[0..n]);
    }

    const term = try child.wait(io());
    if (!term.success()) return error.CommandFailed;
    return output.toOwnedSlice(allocator);
}

/// Run a command to completion, ignoring its output.
pub fn runQuiet(argv: []const []const u8) !void {
    var child = try std.process.spawn(io(), .{ .argv = argv, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore });
    const term = try child.wait(io());
    if (!term.success()) return error.CommandFailed;
}

test "private runtime path lives in a 0700 directory" {
    const allocator = std.testing.allocator;
    const path = try privateRuntimePath(allocator, "probe.wav");
    defer allocator.free(path);
    try std.testing.expect(std.mem.endsWith(u8, path, "/talkies/probe.wav") or std.mem.endsWith(u8, path, "/run/probe.wav"));
    try std.testing.expect(!std.mem.startsWith(u8, path, "/tmp/"));

    const dir = std.fs.path.dirname(path).?;
    const stat = try std.Io.Dir.cwd().statFile(io(), dir, .{});
    try std.testing.expectEqual(@as(std.posix.mode_t, 0o700), stat.permissions.toMode() & 0o777);
}

test "XDG directory resolution" {
    const allocator = std.testing.allocator;

    const config_dir = try getConfigDir(allocator);
    defer allocator.free(config_dir);

    const data_dir = try getDataDir(allocator);
    defer allocator.free(data_dir);

    try std.testing.expect(std.mem.endsWith(u8, config_dir, "/talkies"));
    try std.testing.expect(std.mem.endsWith(u8, data_dir, "/talkies"));
}

/// Write all of `bytes` to standard output (for machine-readable command
/// output such as `talkies --version`; logs go to stderr).
pub fn writeStdout(bytes: []const u8) error{WriteFailed}!void {
    var rest = bytes;
    while (rest.len > 0) {
        const rc = std.os.linux.write(1, rest.ptr, rest.len);
        switch (std.os.linux.errno(rc)) {
            .SUCCESS => rest = rest[rc..],
            .INTR => continue,
            else => return error.WriteFailed,
        }
    }
}
