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
    if (@import("builtin").mode == .Debug) {
        std.debug.print("[DEBUG] " ++ fmt ++ "\n", args);
    }
}

/// Get XDG config directory (~/.config/talkies)
pub fn getConfigDir(allocator: std.mem.Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    const xdg_config = std.posix.getenv("XDG_CONFIG_HOME");

    if (xdg_config) |config_base| {
        return std.fmt.allocPrint(allocator, "{s}/talkies", .{config_base});
    } else {
        return std.fmt.allocPrint(allocator, "{s}/.config/talkies", .{home});
    }
}

/// Get XDG data directory (~/.local/share/talkies)
pub fn getDataDir(allocator: std.mem.Allocator) ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    const xdg_data = std.posix.getenv("XDG_DATA_HOME");

    if (xdg_data) |data_base| {
        return std.fmt.allocPrint(allocator, "{s}/talkies", .{data_base});
    } else {
        return std.fmt.allocPrint(allocator, "{s}/.local/share/talkies", .{home});
    }
}

/// Ensure a directory exists, creating it if necessary
pub fn ensureDir(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };
}

/// Play a sound effect asynchronously (non-blocking)
/// Uses aplay for WAV playback (part of alsa-utils, should already be installed)
pub fn playSound(sound_file: []const u8) void {
    // Spawn process in background - don't wait for it to complete
    var child = std.process.Child.init(&[_][]const u8{ "aplay", "-q", sound_file }, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    // Spawn and detach - fire and forget
    _ = child.spawn() catch {
        // Silently fail if aplay not installed or sound file missing
        return;
    };
    // Don't wait - let it play in background
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
