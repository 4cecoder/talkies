const std = @import("std");
const utils = @import("utils.zig");

/// Clipboard manager for X11 and Wayland
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

    fn copyWayland(self: *Clipboard, text: []const u8) !void {
        // Use wl-copy
        const argv = &[_][]const u8{ "wl-copy", text };
        var child = std.process.Child.init(argv, self.allocator);
        _ = try child.spawnAndWait();
        utils.log("Copied to Wayland clipboard", .{});
    }

    fn copyX11(self: *Clipboard, text: []const u8) !void {
        // Use xclip
        const argv = &[_][]const u8{ "xclip", "-selection", "clipboard" };
        var child = std.process.Child.init(argv, self.allocator);
        child.stdin_behavior = .Pipe;
        try child.spawn();

        if (child.stdin) |stdin| {
            try stdin.writeAll(text);
            stdin.close();
        }

        _ = try child.wait();
        utils.log("Copied to X11 clipboard", .{});
    }
};

/// Detect if running on Wayland
fn detectWayland() bool {
    return std.posix.getenv("WAYLAND_DISPLAY") != null;
}

test "wayland detection" {
    const is_wayland = detectWayland();
    // Just ensure it doesn't crash
    _ = is_wayland;
}
