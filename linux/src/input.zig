const std = @import("std");
const utils = @import("utils.zig");
const Clipboard = @import("clipboard.zig").Clipboard;

/// Text insertion using xdotool
///
/// Dependencies:
/// - X11/Wayland: requires `xdotool` package (apt install xdotool / pacman -S xdotool)
/// Note: xdotool works on both X11 and Wayland with XWayland
pub const TextInserter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TextInserter {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextInserter) void {
        _ = self;
    }

    /// Insert text at cursor position using clipboard + paste (preferred method)
    /// This is more reliable than character-by-character typing
    /// Saves and restores original clipboard content
    pub fn insertTextAtCursor(self: *TextInserter, text: []const u8) !void {
        var clipboard = Clipboard.init(self.allocator);
        defer clipboard.deinit();

        // Save current clipboard contents
        const previous_contents = clipboard.get() catch |err| blk: {
            utils.logDebug("Could not read clipboard (may be empty): {}", .{err});
            break :blk null;
        };
        defer if (previous_contents) |prev| self.allocator.free(prev);

        // Copy new text to clipboard
        try clipboard.copy(text);

        // Small delay to ensure clipboard is ready (50ms)
        std.time.sleep(50 * std.time.ns_per_ms);

        // Simulate Ctrl+V paste
        try self.paste();

        // Delay before restoring clipboard (200ms)
        std.time.sleep(200 * std.time.ns_per_ms);

        // Restore previous clipboard contents
        if (previous_contents) |prev| {
            clipboard.copy(prev) catch |err| {
                utils.logError("Failed to restore clipboard: {}", .{err});
            };
        }

        utils.log("Inserted text at cursor", .{});
    }

    /// Simulate Ctrl+V paste (low-level method)
    pub fn paste(self: *TextInserter) !void {
        const argv = &[_][]const u8{ "xdotool", "key", "ctrl+v" };
        var child = std.process.Child.init(argv, self.allocator);
        const term = try child.spawnAndWait();

        if (term != .Exited or term.Exited != 0) {
            return error.XdotoolFailed;
        }

        utils.logDebug("Executed paste command", .{});
    }

    /// Type text directly character-by-character (alternative to paste)
    /// May have ordering issues with some applications, prefer insertTextAtCursor
    pub fn typeText(self: *TextInserter, text: []const u8) !void {
        const argv = &[_][]const u8{ "xdotool", "type", "--delay", "5", "--", text };
        var child = std.process.Child.init(argv, self.allocator);
        const term = try child.spawnAndWait();

        if (term != .Exited or term.Exited != 0) {
            return error.XdotoolFailed;
        }

        utils.log("Typed text", .{});
    }
};

test "text inserter initialization" {
    const allocator = std.testing.allocator;
    const inserter = TextInserter.init(allocator);

    // Just verify initialization doesn't crash
    try std.testing.expect(inserter.allocator.vtable == allocator.vtable);
}
