// MIT License
//
// Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors
// Adapted for Talkies by Talkies contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Original source: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/gtk/winproto.zig
// Modifications for Talkies:
// - Heavily simplified - removed GDK/GTK windowing abstractions
// - Focused on platform detection only (X11 vs Wayland)
// - Removed window-specific state management (Talkies uses simpler UI)
// - Kept protocol enumeration pattern from Ghostty

const std = @import("std");

/// The underlying windowing protocol in use on Linux.
/// This determines how we interact with the display server.
pub const Protocol = enum {
    /// Unknown or unsupported protocol
    unknown,

    /// Wayland display protocol
    /// Modern replacement for X11, provides better security and performance.
    /// Supports features like per-monitor DPI, secure input handling.
    wayland,

    /// X11 display protocol
    /// Traditional X Window System, widely supported across Linux distributions.
    /// Required for some legacy applications and tools.
    x11,

    /// Detects the current windowing protocol from environment variables.
    /// This is the recommended way to determine the protocol at runtime.
    pub fn detect() Protocol {
        // Check WAYLAND_DISPLAY first (most reliable for Wayland)
        if (std.process.hasEnvVarConstant("WAYLAND_DISPLAY")) {
            return .wayland;
        }

        // Check XDG_SESSION_TYPE (set by display managers)
        const session_type = std.process.getEnvVarOwned(
            std.heap.page_allocator,
            "XDG_SESSION_TYPE",
        ) catch {
            // If we can't get XDG_SESSION_TYPE, fall back to checking DISPLAY
            if (std.process.hasEnvVarConstant("DISPLAY")) {
                return .x11;
            }
            return .unknown;
        };
        defer std.heap.page_allocator.free(session_type);

        if (std.mem.eql(u8, session_type, "wayland")) {
            return .wayland;
        } else if (std.mem.eql(u8, session_type, "x11")) {
            return .x11;
        }

        // Final fallback: check DISPLAY for X11
        if (std.process.hasEnvVarConstant("DISPLAY")) {
            return .x11;
        }

        return .unknown;
    }

    /// Returns a human-readable name for the protocol.
    pub fn name(self: Protocol) []const u8 {
        return switch (self) {
            .unknown => "Unknown",
            .wayland => "Wayland",
            .x11 => "X11",
        };
    }

    /// Returns whether this protocol supports modern features like
    /// fractional scaling and secure input.
    pub fn isModern(self: Protocol) bool {
        return switch (self) {
            .wayland => true,
            .x11 => false,
            .unknown => false,
        };
    }

    /// Returns whether clipboard integration is available.
    /// Both X11 and Wayland support clipboard, but with different APIs.
    pub fn supportsClipboard(self: Protocol) bool {
        return switch (self) {
            .wayland => true,
            .x11 => true,
            .unknown => false,
        };
    }

    /// Returns whether global hotkeys are supported.
    /// X11 has reliable global hotkey support via XGrabKey.
    /// Wayland requires compositor-specific protocols.
    pub fn supportsGlobalHotkeys(self: Protocol) bool {
        return switch (self) {
            .x11 => true,
            // Wayland support depends on compositor, generally more restricted
            .wayland => false,
            .unknown => false,
        };
    }
};

test "Protocol.detect" {
    // This test just ensures the function doesn't crash
    // Actual protocol detection depends on environment
    const proto = Protocol.detect();
    _ = proto; // Suppress unused variable warning
}

test "Protocol.name" {
    const testing = std.testing;

    try testing.expectEqualStrings("Unknown", Protocol.unknown.name());
    try testing.expectEqualStrings("Wayland", Protocol.wayland.name());
    try testing.expectEqualStrings("X11", Protocol.x11.name());
}

test "Protocol.isModern" {
    const testing = std.testing;

    try testing.expect(!Protocol.unknown.isModern());
    try testing.expect(Protocol.wayland.isModern());
    try testing.expect(!Protocol.x11.isModern());
}

test "Protocol.supportsClipboard" {
    const testing = std.testing;

    try testing.expect(!Protocol.unknown.supportsClipboard());
    try testing.expect(Protocol.wayland.supportsClipboard());
    try testing.expect(Protocol.x11.supportsClipboard());
}

test "Protocol.supportsGlobalHotkeys" {
    const testing = std.testing;

    try testing.expect(!Protocol.unknown.supportsGlobalHotkeys());
    try testing.expect(!Protocol.wayland.supportsGlobalHotkeys());
    try testing.expect(Protocol.x11.supportsGlobalHotkeys());
}
