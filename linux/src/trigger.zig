//! Hotkey interpretation shared by every input source (X11 grab, compositor
//! bindings over WebSocket, HUD button). Ports the macOS AppDelegate logic:
//!
//! * Press while idle starts recording immediately.
//! * If the key is still held after `threshold_ms` it is push-to-talk and the
//!   release stops recording.
//! * A quicker tap is click-to-record: recording continues until the next press.
//! * Any press while recording stops it.

const std = @import("std");

pub const Action = enum { none, start, stop };

pub const Trigger = struct {
    threshold_ms: i64,
    key_down: bool = false,
    press_ms: i64 = 0,
    waiting_for_release: bool = false,

    pub fn init(threshold_seconds: f64) Trigger {
        return .{ .threshold_ms = @intFromFloat(@round(threshold_seconds * 1000.0)) };
    }

    pub fn press(self: *Trigger, now_ms: i64, is_recording: bool) Action {
        // Auto-repeat or duplicate press while the key is already held.
        if (self.key_down) return .none;
        self.key_down = true;
        self.press_ms = now_ms;

        if (is_recording) {
            self.waiting_for_release = false;
            return .stop;
        }
        self.waiting_for_release = true;
        return .start;
    }

    pub fn release(self: *Trigger, now_ms: i64, is_recording: bool) Action {
        if (!self.key_down) return .none;
        self.key_down = false;
        defer self.waiting_for_release = false;

        const held_ms = now_ms - self.press_ms;
        if (self.waiting_for_release and is_recording and held_ms >= self.threshold_ms) {
            return .stop;
        }
        return .none;
    }

    /// A single toggle (HUD button, legacy toggle script) without key state.
    pub fn toggle(self: *Trigger, is_recording: bool) Action {
        self.key_down = false;
        self.waiting_for_release = false;
        return if (is_recording) .stop else .start;
    }
};

test "hold longer than threshold is push-to-talk" {
    var t = Trigger.init(0.15);
    try std.testing.expectEqual(Action.start, t.press(1000, false));
    try std.testing.expectEqual(Action.stop, t.release(1400, true));
}

test "quick tap toggles: recording continues until next press" {
    var t = Trigger.init(0.15);
    try std.testing.expectEqual(Action.start, t.press(1000, false));
    try std.testing.expectEqual(Action.none, t.release(1080, true));
    try std.testing.expectEqual(Action.stop, t.press(5000, true));
    try std.testing.expectEqual(Action.none, t.release(5050, false));
}

test "key auto-repeat presses are ignored" {
    var t = Trigger.init(0.15);
    try std.testing.expectEqual(Action.start, t.press(0, false));
    try std.testing.expectEqual(Action.none, t.press(30, true));
    try std.testing.expectEqual(Action.none, t.press(60, true));
    try std.testing.expectEqual(Action.stop, t.release(900, true));
}

test "release without a press is ignored" {
    var t = Trigger.init(0.15);
    try std.testing.expectEqual(Action.none, t.release(10, false));
}

test "threshold is configurable" {
    var t = Trigger.init(0.5);
    _ = t.press(0, false);
    try std.testing.expectEqual(Action.none, t.release(300, true));
}
