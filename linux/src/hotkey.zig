const std = @import("std");
const utils = @import("utils.zig");

// X11 C bindings
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/XKBlib.h");
});

/// X11 error handler that ignores errors (for graceful grab failures)
fn ignoreErrorHandler(_: ?*c.Display, _: [*c]c.XErrorEvent) callconv(.c) c_int {
    return 0;
}

/// Global hotkey listener for X11
pub const HotkeyListener = struct {
    allocator: std.mem.Allocator,
    display: ?*c.Display = null,
    root_window: c.Window = 0,
    running: bool = false,

    /// Check if there are pending X events (non-blocking)
    pub fn hasPendingEvents(self: *HotkeyListener) bool {
        if (self.display) |display| {
            return c.XPending(display) > 0;
        }
        return false;
    }

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
        // Try multiple keysyms that might be Right Alt
        const keysyms = [_]c_ulong{
            c.XK_Alt_R,
            c.XK_ISO_Level3_Shift,
            c.XK_Meta_R,
        };

        // Try different modifier combinations to ensure we catch the key
        const modifiers = [_]c_uint{
            c.AnyModifier, // Try any modifier first
            0, // No modifiers
            c.Mod1Mask, // Alt
            c.Mod3Mask, // Mode_switch
            c.Mod5Mask, // ISO_Level3_Shift
        };

        var grabbed = false;
        for (keysyms) |keysym| {
            const keycode = c.XKeysymToKeycode(self.display.?, keysym);
            if (keycode != 0) {
                utils.log("Trying to grab keycode {d} for keysym {d}", .{ keycode, keysym });

                // Try each modifier combination
                for (modifiers) |modifier| {
                    // Set error handler to ignore BadAccess errors
                    _ = c.XSetErrorHandler(@ptrCast(&ignoreErrorHandler));

                    _ = c.XGrabKey(
                        self.display.?,
                        @intCast(keycode),
                        modifier,
                        self.root_window,
                        1, // owner_events = true - allow events to propagate
                        c.GrabModeAsync,
                        c.GrabModeAsync,
                    );

                    _ = c.XSync(self.display.?, 0);

                    // Restore default error handler
                    _ = c.XSetErrorHandler(null);

                    utils.log("Grabbed keycode {d} with modifier {d}", .{ keycode, modifier });
                    grabbed = true;
                }
            }
        }

        if (!grabbed) {
            utils.log("Warning: Failed to grab Right Alt key", .{});
        }

        _ = c.XSelectInput(self.display.?, self.root_window, c.KeyPressMask | c.KeyReleaseMask);
        _ = c.XSync(self.display.?, 0);
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

        // Check multiple keysyms for Right Alt
        const keysyms = [_]c_ulong{
            c.XK_Alt_R,
            c.XK_ISO_Level3_Shift,
            c.XK_Meta_R,
        };

        switch (event.type) {
            c.KeyPress => {
                for (keysyms) |keysym| {
                    const keycode = c.XKeysymToKeycode(self.display.?, keysym);
                    if (keycode != 0 and event.xkey.keycode == keycode) {
                        utils.log("Key press detected: keycode {d}", .{event.xkey.keycode});
                        return .press;
                    }
                }
                // Debug: show what key was pressed
                utils.log("Unknown key press: keycode {d}", .{event.xkey.keycode});
            },
            c.KeyRelease => {
                for (keysyms) |keysym| {
                    const keycode = c.XKeysymToKeycode(self.display.?, keysym);
                    if (keycode != 0 and event.xkey.keycode == keycode) {
                        utils.log("Key release detected: keycode {d}", .{event.xkey.keycode});
                        return .release;
                    }
                }
                // Debug: show what key was released
                utils.log("Unknown key release: keycode {d}", .{event.xkey.keycode});
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
