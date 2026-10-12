const std = @import("std");
const utils = @import("core").utils;
const Clipboard = @import("clipboard.zig").Clipboard;
const linux = std.os.linux;

// C imports for uinput
const c = @import("c_input");

/// Text insertion using native Linux uinput
///
/// No external dependencies - uses kernel uinput interface directly
/// Works on both X11 and Wayland without XWayland
/// Delay between setting the clipboard and sending the paste keystroke.
const clipboard_settle_ms = 300;
/// Delay between the paste keystroke and restoring the old clipboard. The
/// target app reads the clipboard asynchronously after receiving the key.
const restore_delay_ms = 400;

const key_event_gap_ms = 15;
const device_settle_ms = 150;
const supported_keys = [_]c_int{ c.KEY_LEFTCTRL, c.KEY_LEFTSHIFT, c.KEY_LEFTALT, c.KEY_V, c.KEY_INSERT };

pub const KeyCombo = struct { ctrl: bool = false, shift: bool = false, alt: bool = false, key: c_int = c.KEY_V };

/// Parse "ctrl+v", "ctrl+shift+v", "shift+Insert" (case-insensitive).
pub fn parseKeybind(keybind: []const u8) !KeyCombo {
    var combo: KeyCombo = .{};
    var it = std.mem.tokenizeScalar(u8, keybind, '+');
    while (it.next()) |raw| {
        const part = std.mem.trim(u8, raw, &std.ascii.whitespace);
        if (std.ascii.eqlIgnoreCase(part, "ctrl") or std.ascii.eqlIgnoreCase(part, "control")) {
            combo.ctrl = true;
        } else if (std.ascii.eqlIgnoreCase(part, "shift")) {
            combo.shift = true;
        } else if (std.ascii.eqlIgnoreCase(part, "alt")) {
            combo.alt = true;
        } else if (std.ascii.eqlIgnoreCase(part, "v")) {
            combo.key = c.KEY_V;
        } else if (std.ascii.eqlIgnoreCase(part, "insert")) {
            combo.key = c.KEY_INSERT;
        } else {
            return error.UnsupportedPasteKey;
        }
    }
    return combo;
}

fn ioctlChecked(fd: std.posix.fd_t, request: c_ulong, arg: c_ulong) !void {
    if (c.ioctl(fd, request, arg) < 0) return error.UinputIoctlFailed;
}

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
            if (c.ioctl(fd, c.UI_DEV_DESTROY, @as(c_int, 0)) < 0) {
                utils.logError("Failed to destroy virtual keyboard", .{});
            }
            _ = linux.close(fd);
            self.uinput_fd = null;
        }
    }

    /// Insert text at cursor position using clipboard + paste.
    /// keybind: paste keybind (e.g. "ctrl+v", "ctrl+shift+v", "shift+Insert").
    /// restore_clipboard: like macOS, put the previous text clipboard back
    /// once the target app has had time to read the pasted text.
    pub fn insertTextAtCursor(self: *TextInserter, text: []const u8, keybind: []const u8, restore_clipboard: bool) !void {
        var clipboard = Clipboard.init(self.allocator);
        defer clipboard.deinit();

        // Capture first; an empty or non-text clipboard simply isn't restored.
        const previous: ?[]u8 = if (restore_clipboard) clipboard.get() catch |err| blk: {
            utils.logDebug("No text clipboard to restore: {}", .{err});
            break :blk null;
        } else null;
        defer if (previous) |p| self.allocator.free(p);

        try clipboard.copy(text);

        // Give the clipboard owner time to settle (Wayland needs longer than
        // macOS' 50ms) so we never paste stale content.
        utils.sleepNanoseconds(clipboard_settle_ms * std.time.ns_per_ms);

        try self.pasteNative(keybind);

        if (previous) |p| {
            if (p.len > 0 and !std.mem.eql(u8, p, text)) {
                utils.sleepNanoseconds(restore_delay_ms * std.time.ns_per_ms);
                clipboard.copy(p) catch |err| {
                    utils.logError("Failed to restore previous clipboard: {}", .{err});
                };
            }
        }
        utils.log("Inserted text at cursor", .{});
    }

    /// Simulate paste using native Linux uinput (no external tools)
    /// Parses keybind string (e.g. "ctrl+v", "ctrl+shift+v", "shift+Insert")
    fn pasteNative(self: *TextInserter, keybind: []const u8) !void {
        const combo = try parseKeybind(keybind);
        try self.ensureDevice();

        const modifiers = [_]struct { on: bool, key: c_int }{
            .{ .on = combo.ctrl, .key = c.KEY_LEFTCTRL },
            .{ .on = combo.shift, .key = c.KEY_LEFTSHIFT },
            .{ .on = combo.alt, .key = c.KEY_LEFTALT },
        };
        for (modifiers) |m| if (m.on) try self.tapKey(m.key, 1);
        try self.tapKey(combo.key, 1);
        try self.tapKey(combo.key, 0);
        var i: usize = modifiers.len;
        while (i > 0) {
            i -= 1;
            if (modifiers[i].on) try self.tapKey(modifiers[i].key, 0);
        }
        utils.logDebug("Executed native paste command ({s})", .{keybind});
    }

    fn tapKey(self: *TextInserter, key: c_int, value: i32) !void {
        try self.emitEvent(c.EV_KEY, key, value);
        try self.emitEvent(c.EV_SYN, c.SYN_REPORT, 0);
        utils.sleepNanoseconds(key_event_gap_ms * std.time.ns_per_ms);
    }

    /// Create the virtual keyboard once and keep it for the daemon's
    /// lifetime: re-creating it per paste cost ~100ms of device settle time
    /// and spammed compositors with hotplug events.
    fn ensureDevice(self: *TextInserter) !void {
        if (self.uinput_fd != null) return;

        const fd = try std.posix.openat(
            std.posix.AT.FDCWD,
            "/dev/uinput",
            .{ .ACCMODE = .WRONLY, .NONBLOCK = true },
            0,
        );
        errdefer _ = linux.close(fd);

        try ioctlChecked(fd, c.UI_SET_EVBIT, c.EV_KEY);
        try ioctlChecked(fd, c.UI_SET_EVBIT, c.EV_SYN);
        for (supported_keys) |key| try ioctlChecked(fd, c.UI_SET_KEYBIT, @intCast(key));

        var setup: c.struct_uinput_setup = std.mem.zeroes(c.struct_uinput_setup);
        const name = "Talkies Virtual Keyboard";
        @memcpy(setup.name[0..name.len], name);
        setup.id.bustype = c.BUS_USB;
        setup.id.vendor = 0x1234;
        setup.id.product = 0x5678;
        setup.id.version = 1;
        if (c.ioctl(fd, c.UI_DEV_SETUP, &setup) < 0) return error.UinputSetupFailed;
        if (c.ioctl(fd, c.UI_DEV_CREATE, @as(c_int, 0)) < 0) return error.UinputCreateFailed;

        self.uinput_fd = fd;
        // Give the compositor time to register the new device (first use only).
        utils.sleepNanoseconds(device_settle_ms * std.time.ns_per_ms);
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
        const written = std.c.write(self.uinput_fd.?, bytes.ptr, bytes.len);

        if (written < 0) return error.InputOutput;

        if (@as(usize, @intCast(written)) != bytes.len) {
            return error.PartialWrite;
        }
    }

    /// Fallback: Simulate Ctrl+V paste using xdotool (if native fails)
    pub fn pasteFallback(_: *TextInserter) !void {
        const argv = &[_][]const u8{ "xdotool", "key", "ctrl+v" };
        var child = try std.process.spawn(utils.io(), .{ .argv = argv });
        const term = try child.wait(utils.io());

        if (!term.success()) {
            return error.XdotoolFailed;
        }

        utils.logDebug("Executed fallback paste command (xdotool)", .{});
    }
};

test "paste keybind parsing" {
    const terminal = try parseKeybind("Ctrl+Shift+V");
    try std.testing.expect(terminal.ctrl and terminal.shift and !terminal.alt);
    try std.testing.expectEqual(@as(c_int, c.KEY_V), terminal.key);
    const insert = try parseKeybind("shift+Insert");
    try std.testing.expect(insert.shift and !insert.ctrl);
    try std.testing.expectEqual(@as(c_int, c.KEY_INSERT), insert.key);
    try std.testing.expectError(error.UnsupportedPasteKey, parseKeybind("ctrl+q"));
}

test "text inserter initialization" {
    const allocator = std.testing.allocator;
    var inserter = TextInserter.init(allocator);
    defer inserter.deinit();

    // Just verify initialization doesn't crash
    try std.testing.expect(inserter.allocator.vtable == allocator.vtable);
}
