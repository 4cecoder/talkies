const std = @import("std");
const utils = @import("utils.zig");

// X11 C bindings
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
});

/// Global hotkey listener for X11
pub const HotkeyListener = struct {
    allocator: std.mem.Allocator,
    display: ?*c.Display = null,
    root_window: c.Window = 0,
    running: bool = false,

    pub fn init(allocator: std.mem.Allocator) HotkeyListener {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HotkeyListener) void {
        if (self.display) |display| {
            _ = c.XCloseDisplay(display);
            self.display = null;
        }
    }

    /// Start listening for Right Alt key events
    pub fn start(self: *HotkeyListener) !void {
        // Open X11 display
        self.display = c.XOpenDisplay(null);
        if (self.display == null) {
            return error.X11DisplayOpenFailed;
        }

        self.root_window = c.XDefaultRootWindow(self.display.?);

        // Grab Right Alt key (Alt_R / ISO_Level3_Shift)
        // Keycode 108 is typically Right Alt
        const right_alt_keycode = c.XKeysymToKeycode(self.display.?, c.XK_Alt_R);

        // Grab the key with any modifiers
        const result = c.XGrabKey(
            self.display.?,
            @intCast(right_alt_keycode),
            c.AnyModifier,
            self.root_window,
            1, // owner_events = true
            c.GrabModeAsync,
            c.GrabModeAsync,
        );

        if (result == 0) {
            utils.log("Warning: Failed to grab Right Alt key", .{});
        }

        _ = c.XSelectInput(self.display.?, self.root_window, c.KeyPressMask | c.KeyReleaseMask);
        self.running = true;

        utils.log("Hotkey listener started (Right Alt)", .{});
    }

    /// Stop listening for hotkey events
    pub fn stop(self: *HotkeyListener) void {
        self.running = false;

        if (self.display) |display| {
            const right_alt_keycode = c.XKeysymToKeycode(display, c.XK_Alt_R);
            _ = c.XUngrabKey(display, @intCast(right_alt_keycode), c.AnyModifier, self.root_window);
        }

        utils.log("Hotkey listener stopped", .{});
    }

    /// Poll for next key event (blocking)
    /// Returns: .press or .release for Right Alt, null for other keys
    pub fn poll(self: *HotkeyListener) !?KeyEvent {
        if (!self.running or self.display == null) {
            return null;
        }

        var event: c.XEvent = undefined;
        _ = c.XNextEvent(self.display.?, &event);

        const right_alt_keycode = c.XKeysymToKeycode(self.display.?, c.XK_Alt_R);

        switch (event.type) {
            c.KeyPress => {
                if (event.xkey.keycode == right_alt_keycode) {
                    return .press;
                }
            },
            c.KeyRelease => {
                if (event.xkey.keycode == right_alt_keycode) {
                    return .release;
                }
            },
            else => {},
        }

        return null;
    }
};

pub const KeyEvent = enum {
    press,
    release,
};

test "hotkey listener initialization" {
    const allocator = std.testing.allocator;
    var listener = HotkeyListener.init(allocator);
    defer listener.deinit();

    try std.testing.expect(listener.display == null);
    try std.testing.expect(listener.running == false);
}
