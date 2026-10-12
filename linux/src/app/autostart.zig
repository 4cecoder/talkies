//! "Launch at Login" (macOS SMAppService): an XDG autostart entry at
//! $XDG_CONFIG_HOME/autostart/app.talkies.Talkies.desktop. Desktop
//! environments and most Wayland compositors (via xdg-autostart) start it at
//! login. The file's presence is the setting, so it is never out of sync.

const std = @import("std");
const utils = @import("core").utils;

const file_name = "app.talkies.Talkies.desktop";

/// Caller owns the returned path.
fn entryPath(allocator: std.mem.Allocator) ![]u8 {
    if (utils.getEnv("XDG_CONFIG_HOME")) |base| {
        if (base.len > 0) return std.fmt.allocPrint(allocator, "{s}/autostart/{s}", .{ base, file_name });
    }
    const home = utils.getEnv("HOME") orelse return error.NoHomeDir;
    return std.fmt.allocPrint(allocator, "{s}/.config/autostart/{s}", .{ home, file_name });
}

pub fn isEnabled(allocator: std.mem.Allocator) bool {
    const path = entryPath(allocator) catch return false;
    defer allocator.free(path);
    std.Io.Dir.cwd().access(utils.io(), path, .{}) catch return false;
    return true;
}

pub fn setEnabled(allocator: std.mem.Allocator, enabled: bool) !void {
    const path = try entryPath(allocator);
    defer allocator.free(path);
    if (!enabled) {
        std.Io.Dir.deleteFileAbsolute(utils.io(), path) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
        return;
    }

    var exe_buf: [std.fs.max_path_bytes]u8 = undefined;
    const rc = std.os.linux.readlink("/proc/self/exe", &exe_buf, exe_buf.len);
    if (std.os.linux.errno(rc) != .SUCCESS) return error.ExecutableNotFound;
    const content = try desktopEntry(allocator, exe_buf[0..rc]);
    defer allocator.free(content);

    try utils.ensureDir(std.fs.path.dirname(path) orelse return error.InvalidPath);
    const file = try std.Io.Dir.cwd().createFile(utils.io(), path, .{});
    defer file.close(utils.io());
    try file.writeStreamingAll(utils.io(), content);
}

/// The autostart entry for the daemon at `exe`. Caller owns the result.
fn desktopEntry(allocator: std.mem.Allocator, exe: []const u8) ![]u8 {
    // Desktop Exec quoting: wrap in double quotes, escape " ` $ \.
    var quoted: std.Io.Writer.Allocating = .init(allocator);
    defer quoted.deinit();
    try quoted.writer.writeByte('"');
    for (exe) |c| {
        if (c == '"' or c == '`' or c == '$' or c == '\\') try quoted.writer.writeByte('\\');
        try quoted.writer.writeByte(c);
    }
    try quoted.writer.writeByte('"');
    return std.fmt.allocPrint(allocator,
        \\[Desktop Entry]
        \\Type=Application
        \\Name=Talkies
        \\Comment=On-device dictation
        \\Exec={s} daemon
        \\Icon=talkies
        \\Terminal=false
        \\NoDisplay=true
        \\X-GNOME-Autostart-enabled=true
        \\
    , .{quoted.written()});
}

test "autostart entry quotes the executable path" {
    const entry = try desktopEntry(std.testing.allocator, "/opt/My Apps/talkies");
    defer std.testing.allocator.free(entry);
    try std.testing.expect(std.mem.indexOf(u8, entry, "Exec=\"/opt/My Apps/talkies\" daemon\n") != null);
    try std.testing.expect(std.mem.startsWith(u8, entry, "[Desktop Entry]\nType=Application\n"));
}

test "autostart entry escapes desktop-entry specials" {
    const entry = try desktopEntry(std.testing.allocator, "/tmp/a$b\"c");
    defer std.testing.allocator.free(entry);
    try std.testing.expect(std.mem.indexOf(u8, entry, "Exec=\"/tmp/a\\$b\\\"c\" daemon") != null);
}
