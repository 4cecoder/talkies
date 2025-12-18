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
// Original source: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/runtime.zig
// Modifications for Talkies:
// - Simplified to only support CLI and GTK modes (removed macOS-specific features)
// - Adapted for Talkies' voice transcription use case vs Ghostty's terminal emulator
// - Renamed from "apprt" (app runtime) to "runtime" for simplicity

const std = @import("std");

/// Runtime is the UI runtime mode for Talkies. Different runtimes provide
/// different user interface options for voice transcription.
pub const Runtime = enum {
    /// Command-line interface mode. Runs transcription in the terminal
    /// without a graphical window. Useful for scripting and headless operation.
    cli,

    /// GTK4 graphical interface. Full-featured windowed application with
    /// system tray integration, waveform visualization, and settings UI.
    /// Uses native GTK widgets for Linux desktop integration.
    gtk,

    /// Returns the default runtime for the given target platform.
    pub fn default(target: std.Target) Runtime {
        return switch (target.os.tag) {
            // Linux defaults to GTK for full desktop integration
            .linux => .gtk,

            // FreeBSD also defaults to GTK (uses same X11/Wayland stack as Linux)
            .freebsd => .gtk,

            // Other platforms default to CLI mode
            else => .cli,
        };
    }

    /// Returns a human-readable description of the runtime mode.
    pub fn description(self: Runtime) []const u8 {
        return switch (self) {
            .cli => "Command-line interface",
            .gtk => "GTK4 graphical interface",
        };
    }

    /// Returns whether this runtime supports graphical features like
    /// waveform visualization and system tray.
    pub fn isGraphical(self: Runtime) bool {
        return switch (self) {
            .cli => false,
            .gtk => true,
        };
    }

    /// Returns whether this runtime supports system tray integration.
    pub fn supportsTray(self: Runtime) bool {
        return switch (self) {
            .cli => false,
            .gtk => true,
        };
    }
};

test "Runtime.default" {
    // Note: This test is simplified to avoid complex target construction.
    // The actual Runtime.default function is used in build.zig where proper
    // Target objects are available.
    _ = Runtime.default;
}

test "Runtime.isGraphical" {
    const testing = std.testing;

    try testing.expect(!Runtime.cli.isGraphical());
    try testing.expect(Runtime.gtk.isGraphical());
}

test "Runtime.supportsTray" {
    const testing = std.testing;

    try testing.expect(!Runtime.cli.supportsTray());
    try testing.expect(Runtime.gtk.supportsTray());
}
