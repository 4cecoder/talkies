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
    /// Leaves transcription in clipboard for easy manual pasting
    /// keybind: paste keybind in xdotool format (e.g. "ctrl+v", "ctrl+shift+v")
    pub fn insertTextAtCursor(self: *TextInserter, text: []const u8, keybind: []const u8) !void {
        var clipboard = Clipboard.init(self.allocator);
        defer clipboard.deinit();

        utils.logDebug("About to paste: \"{s}\"", .{text});

        // Copy new text to clipboard
        try clipboard.copy(text);

        // Small delay to ensure clipboard is ready (100ms for Wayland)
        std.posix.nanosleep(0, 100 * std.time.ns_per_ms);

        // Simulate paste using native uinput with configured keybind
        try self.pasteNative(keybind);

        // Leave transcription in clipboard for easy re-pasting
        utils.log("Inserted text at cursor", .{});
    }

    /// Simulate paste using native Linux uinput (no external tools)
    /// Parses keybind string (e.g. "ctrl+v", "ctrl+shift+v", "shift+Insert")
    fn pasteNative(self: *TextInserter, keybind: []const u8) !void {
        // Parse keybind into modifier + key
        var has_ctrl = false;
        var has_shift = false;
        var has_alt = false;
        var main_key: c_int = c.KEY_V; // default

        var it = std.mem.tokenizeAny(u8, keybind, "+");
        while (it.next()) |part| {
            // Compare case-insensitively
            if (std.ascii.eqlIgnoreCase(part, "ctrl")) {
                has_ctrl = true;
            } else if (std.ascii.eqlIgnoreCase(part, "shift")) {
                has_shift = true;
            } else if (std.ascii.eqlIgnoreCase(part, "alt")) {
                has_alt = true;
            } else if (std.ascii.eqlIgnoreCase(part, "v")) {
                main_key = c.KEY_V;
            } else if (std.ascii.eqlIgnoreCase(part, "insert")) {
                main_key = c.KEY_INSERT;
            }
        }

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

        _ = c.ioctl(fd, c.UI_SET_EVBIT, ev_key);
        _ = c.ioctl(fd, c.UI_SET_EVBIT, ev_syn);

        if (has_ctrl) _ = c.ioctl(fd, c.UI_SET_KEYBIT, @as(c_ulong, c.KEY_LEFTCTRL));
        if (has_shift) _ = c.ioctl(fd, c.UI_SET_KEYBIT, @as(c_ulong, c.KEY_LEFTSHIFT));
        if (has_alt) _ = c.ioctl(fd, c.UI_SET_KEYBIT, @as(c_ulong, c.KEY_LEFTALT));
        _ = c.ioctl(fd, c.UI_SET_KEYBIT, @as(c_ulong, @intCast(main_key)));

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

        // Press modifiers
        if (has_ctrl) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTCTRL, 1);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
            std.posix.nanosleep(0, 20 * std.time.ns_per_ms);
        }
        if (has_shift) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTSHIFT, 1);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
            std.posix.nanosleep(0, 20 * std.time.ns_per_ms);
        }
        if (has_alt) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTALT, 1);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
            std.posix.nanosleep(0, 20 * std.time.ns_per_ms);
        }

        // Press main key
        try self.emitEvent(c.EV_KEY, main_key, 1);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
        std.posix.nanosleep(0, 20 * std.time.ns_per_ms);

        // Release main key
        try self.emitEvent(c.EV_KEY, main_key, 0);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
        std.posix.nanosleep(0, 20 * std.time.ns_per_ms);

        // Release modifiers (reverse order)
        if (has_alt) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTALT, 0);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
            std.posix.nanosleep(0, 20 * std.time.ns_per_ms);
        }
        if (has_shift) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTSHIFT, 0);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
            std.posix.nanosleep(0, 20 * std.time.ns_per_ms);
        }
        if (has_ctrl) {
            try self.emitEvent(c.EV_KEY, c.KEY_LEFTCTRL, 0);
            try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
        }

        // Cleanup
        _ = c.ioctl(fd, c.UI_DEV_DESTROY, @as(c_int, 0));
        std.posix.close(fd);
        self.uinput_fd = null;

        utils.logDebug("Executed native paste command ({s})", .{keybind});
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
