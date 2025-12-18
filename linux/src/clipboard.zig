const std = @import("std");
const utils = @import("utils.zig");

/// Clipboard manager for X11 and Wayland
///
/// Dependencies:
/// - X11: requires `xclip` package (apt install xclip / pacman -S xclip)
/// - Wayland: requires `wl-clipboard` package (apt install wl-clipboard / pacman -S wl-clipboard)
pub const Clipboard = struct {
    allocator: std.mem.Allocator,
    is_wayland: bool,

    pub fn init(allocator: std.mem.Allocator) Clipboard {
        const is_wayland = detectWayland();
        return .{
            .allocator = allocator,
            .is_wayland = is_wayland,
        };
    }

    pub fn deinit(self: *Clipboard) void {
        _ = self;
    }

    /// Copy text to clipboard
    pub fn copy(self: *Clipboard, text: []const u8) !void {
        if (self.is_wayland) {
            try self.copyWayland(text);
        } else {
            try self.copyX11(text);
        }
    }

    /// Get current clipboard contents
    /// Caller owns the returned memory and must free it
    pub fn get(self: *Clipboard) ![]u8 {
        if (self.is_wayland) {
            return try self.getWayland();
        } else {
            return try self.getX11();
        }
    }

    fn copyWayland(self: *Clipboard, text: []const u8) !void {
        // Use wl-copy - pass text as stdin for better handling of special chars
        const argv = &[_][]const u8{"wl-copy"};
        var child = std.process.Child.init(argv, self.allocator);
        child.stdin_behavior = .Pipe;
        try child.spawn();

        if (child.stdin) |stdin| {
            try stdin.writeAll(text);
            stdin.close();
        }

        const term = try child.wait();
        if (term != .Exited or term.Exited != 0) {
            return error.WlCopyFailed;
        }
        utils.log("Copied to Wayland clipboard", .{});
    }

    fn copyX11(self: *Clipboard, text: []const u8) !void {
        // Use xclip to copy to clipboard
        const argv = &[_][]const u8{ "xclip", "-selection", "clipboard" };
        var child = std.process.Child.init(argv, self.allocator);
        child.stdin_behavior = .Pipe;
        try child.spawn();

        if (child.stdin) |stdin| {
            try stdin.writeAll(text);
            stdin.close();
        }

        const term = try child.wait();
        if (term != .Exited or term.Exited != 0) {
            return error.XClipFailed;
        }
        utils.log("Copied to X11 clipboard", .{});
    }

    fn getWayland(self: *Clipboard) ![]u8 {
        // Use wl-paste to read clipboard
        const argv = &[_][]const u8{"wl-paste"};
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        const stdout = child.stdout orelse return error.NoStdout;

        // Read from stdout in chunks
        var output_list = std.ArrayList(u8).empty;
        defer output_list.deinit(self.allocator);

        var buffer: [4096]u8 = undefined;
        while (true) {
            const n = try stdout.read(&buffer);
            if (n == 0) break;
            try output_list.appendSlice(self.allocator, buffer[0..n]);
        }

        const term = try child.wait();
        if (term != .Exited or term.Exited != 0) {
            return error.WlPasteFailed;
        }

        utils.logDebug("Read {d} bytes from Wayland clipboard", .{output_list.items.len});
        return try self.allocator.dupe(u8, output_list.items);
    }

    fn getX11(self: *Clipboard) ![]u8 {
        // Use xclip to read clipboard
        const argv = &[_][]const u8{ "xclip", "-selection", "clipboard", "-o" };
        var child = std.process.Child.init(argv, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Ignore;

        try child.spawn();

        const stdout = child.stdout orelse return error.NoStdout;

        // Read from stdout in chunks
        var output_list = std.ArrayList(u8).empty;
        defer output_list.deinit(self.allocator);

        var buffer: [4096]u8 = undefined;
        while (true) {
            const n = try stdout.read(&buffer);
            if (n == 0) break;
            try output_list.appendSlice(self.allocator, buffer[0..n]);
        }

        const term = try child.wait();
        if (term != .Exited or term.Exited != 0) {
            return error.XClipFailed;
        }

        utils.logDebug("Read {d} bytes from X11 clipboard", .{output_list.items.len});
        return try self.allocator.dupe(u8, output_list.items);
    }
};

/// Detect if running on Wayland
/// Checks both WAYLAND_DISPLAY and XDG_SESSION_TYPE for reliability
fn detectWayland() bool {
    // Check WAYLAND_DISPLAY first (most reliable)
    if (std.posix.getenv("WAYLAND_DISPLAY")) |_| {
        return true;
    }

    // Fallback to XDG_SESSION_TYPE
    if (std.posix.getenv("XDG_SESSION_TYPE")) |session_type| {
        return std.mem.eql(u8, session_type, "wayland");
    }

    return false;
}

test "wayland detection" {
    const is_wayland = detectWayland();
    // Just ensure it doesn't crash
    _ = is_wayland;
}
