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
// Original source: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/gtk/gtk_version.zig
// Modifications for Talkies:
// - Simplified to use direct GTK C API instead of Zig GTK bindings
// - Removed dependency on external GTK bindings package
// - Kept core version checking logic intact

const std = @import("std");

extern "c" fn gtk_get_major_version() c_uint;
extern "c" fn gtk_get_minor_version() c_uint;
extern "c" fn gtk_get_micro_version() c_uint;

const log = std.log.scoped(.gtk);

/// Get the runtime GTK version
pub fn getRuntimeVersion() std.SemanticVersion {
    return .{
        .major = gtk_get_major_version(),
        .minor = gtk_get_minor_version(),
        .patch = gtk_get_micro_version(),
    };
}

/// Log the GTK version supplied by the linked runtime library
pub fn logVersion() void {
    log.info("GTK runtime version={}", .{getRuntimeVersion()});
}

/// Verifies that the linked GTK runtime is at least the given version.
pub inline fn atLeast(
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    return versionAtLeast(getRuntimeVersion(), major, minor, micro);
}

/// Verifies that the GTK version at runtime is at least the given version.
///
/// This function should be used in cases where the only the runtime behavior
/// is affected by the version check. For checks which would affect code
/// generation, use `atLeast`.
pub inline fn runtimeAtLeast(
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    const runtime_version = getRuntimeVersion();
    return versionAtLeast(runtime_version, major, minor, micro);
}

fn versionAtLeast(
    version: std.SemanticVersion,
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    return version.order(.{ .major = major, .minor = minor, .patch = micro }) != .lt;
}

/// Verifies that the GTK version at runtime is before the given version.
pub inline fn runtimeUntil(
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    return versionUntil(getRuntimeVersion(), major, minor, micro);
}

fn versionUntil(
    version: std.SemanticVersion,
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    return version.order(.{ .major = major, .minor = minor, .patch = micro }) == .lt;
}

test "atLeast" {
    const testing = std.testing;
    const current: std.SemanticVersion = .{ .major = 4, .minor = 18, .patch = 1 };

    try testing.expect(versionAtLeast(current, 4, 18, 1));
    try testing.expect(!versionAtLeast(current, 4, 18, 2));
    try testing.expect(!versionAtLeast(current, 4, 19, 1));
    try testing.expect(!versionAtLeast(current, 5, 18, 1));
    try testing.expect(versionAtLeast(current, 3, 18, 1));
    try testing.expect(versionAtLeast(current, 3, 19, 1));
    try testing.expect(versionAtLeast(current, 3, 18, 2));
    try testing.expect(versionAtLeast(current, 4, 17, 2));
}

test "runtimeUntil" {
    const testing = std.testing;
    const current: std.SemanticVersion = .{ .major = 4, .minor = 18, .patch = 1 };

    try testing.expect(!versionUntil(current, 4, 18, 1));
    try testing.expect(versionUntil(current, 4, 18, 2));
    try testing.expect(versionUntil(current, 4, 19, 1));
    try testing.expect(versionUntil(current, 5, 18, 1));
    try testing.expect(!versionUntil(current, 3, 18, 1));
    try testing.expect(!versionUntil(current, 3, 19, 1));
    try testing.expect(!versionUntil(current, 3, 18, 2));
    try testing.expect(!versionUntil(current, 4, 17, 2));
}
