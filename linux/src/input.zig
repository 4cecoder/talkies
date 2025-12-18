const std = @import("std");
const utils = @import("utils.zig");
const Clipboard = @import("clipboard.zig").Clipboard;
const linux = std.os.linux;

// C imports for uinput
const c = @cImport({
    @cInclude("linux/uinput.h");
    @cInclude("sys/ioctl.h");
});

/// Text insertion using native Linux uinput
///
/// No external dependencies - uses kernel uinput interface directly
/// Works on both X11 and Wayland without XWayland
pub const TextInserter = struct {
    allocator: std.mem.Allocator,
    uinput_fd: ?std.posix.fd_t = null,

    pub fn init(allocator: std.mem.Allocator) TextInserter {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextInserter) void {
        if (self.uinput_fd) |fd| {
            std.posix.close(fd);
            self.uinput_fd = null;
        }
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

        // Small delay to ensure clipboard is ready (100ms for Wayland)
        std.posix.nanosleep(0, 100 * std.time.ns_per_ms);

        // Simulate Ctrl+V paste using native uinput
        try self.pasteNative();

        // Delay before restoring clipboard (300ms)
        std.posix.nanosleep(0, 300 * std.time.ns_per_ms);

        // Restore previous clipboard contents
        if (previous_contents) |prev| {
            clipboard.copy(prev) catch |err| {
                utils.logError("Failed to restore clipboard: {}", .{err});
            };
        }

        utils.log("Inserted text at cursor", .{});
    }

    /// Simulate Ctrl+V paste using native Linux uinput (no external tools)
    fn pasteNative(self: *TextInserter) !void {
        // Open uinput device
        const fd = try std.posix.open(
            "/dev/uinput",
            .{ .ACCMODE = .WRONLY, .NONBLOCK = true },
            0,
        );
        errdefer std.posix.close(fd);

        self.uinput_fd = fd;

        // Enable key events using C ioctl
        const ev_key: c_ulong = c.EV_KEY;
        const ev_syn: c_ulong = c.EV_SYN;
        const key_ctrl: c_ulong = c.KEY_LEFTCTRL;
        const key_v: c_ulong = c.KEY_V;

        _ = c.ioctl(fd, c.UI_SET_EVBIT, ev_key);
        _ = c.ioctl(fd, c.UI_SET_EVBIT, ev_syn);
        _ = c.ioctl(fd, c.UI_SET_KEYBIT, key_ctrl);
        _ = c.ioctl(fd, c.UI_SET_KEYBIT, key_v);

        // Setup virtual device using C struct
        var setup: c.struct_uinput_setup = undefined;
        @memset(&setup.name, 0);
        const name = "Talkies Virtual Keyboard";
        @memcpy(setup.name[0..name.len], name);
        setup.id.bustype = c.BUS_USB;
        setup.id.vendor = 0x1234;
        setup.id.product = 0x5678;
        setup.id.version = 1;
        setup.ff_effects_max = 0;

        _ = c.ioctl(fd, c.UI_DEV_SETUP, &setup);
        _ = c.ioctl(fd, c.UI_DEV_CREATE, @as(c_int, 0));

        // Small delay for device creation
        std.posix.nanosleep(0, 100 * std.time.ns_per_ms);

        // Press Ctrl
        try self.emitEvent(c.EV_KEY, c.KEY_LEFTCTRL, 1);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);

        // Small delay
        std.posix.nanosleep(0, 20 * std.time.ns_per_ms);

        // Press V
        try self.emitEvent(c.EV_KEY, c.KEY_V, 1);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);

        // Small delay
        std.posix.nanosleep(0, 20 * std.time.ns_per_ms);

        // Release V
        try self.emitEvent(c.EV_KEY, c.KEY_V, 0);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);

        // Small delay
        std.posix.nanosleep(0, 20 * std.time.ns_per_ms);

        // Release Ctrl
        try self.emitEvent(c.EV_KEY, c.KEY_LEFTCTRL, 0);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);

        // Cleanup
        _ = c.ioctl(fd, c.UI_DEV_DESTROY, @as(c_int, 0));
        std.posix.close(fd);
        self.uinput_fd = null;

        utils.logDebug("Executed native paste command (Ctrl+V)", .{});
    }

    /// Emit a single input event
    fn emitEvent(self: *TextInserter, event_type: c_int, code: c_int, value: i32) !void {
        if (self.uinput_fd == null) return error.UinputNotInitialized;

        var event: c.struct_input_event = undefined;
        event.time.tv_sec = 0;
        event.time.tv_usec = 0;
        event.type = @intCast(event_type);
        event.code = @intCast(code);
        event.value = value;

        const bytes = std.mem.asBytes(&event);
        const written = try std.posix.write(self.uinput_fd.?, bytes);

        if (written != bytes.len) {
            return error.PartialWrite;
        }
    }

    /// Fallback: Simulate Ctrl+V paste using xdotool (if native fails)
    pub fn pasteFallback(self: *TextInserter) !void {
        const argv = &[_][]const u8{ "xdotool", "key", "ctrl+v" };
        var child = std.process.Child.init(argv, self.allocator);
        const term = try child.spawnAndWait();

        if (term != .Exited or term.Exited != 0) {
            return error.XdotoolFailed;
        }

        utils.logDebug("Executed fallback paste command (xdotool)", .{});
    }
};

test "text inserter initialization" {
    const allocator = std.testing.allocator;
    var inserter = TextInserter.init(allocator);
    defer inserter.deinit();

    // Just verify initialization doesn't crash
    try std.testing.expect(inserter.allocator.vtable == allocator.vtable);
}
