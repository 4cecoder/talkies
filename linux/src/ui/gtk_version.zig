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

// Direct C imports for GTK4
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

const log = std.log.scoped(.gtk);

/// Compile-time GTK version from headers
pub const comptime_version: std.SemanticVersion = .{
    .major = c.GTK_MAJOR_VERSION,
    .minor = c.GTK_MINOR_VERSION,
    .patch = c.GTK_MICRO_VERSION,
};

/// Get the runtime GTK version
pub fn getRuntimeVersion() std.SemanticVersion {
    return .{
        .major = c.gtk_get_major_version(),
        .minor = c.gtk_get_minor_version(),
        .patch = c.gtk_get_micro_version(),
    };
}

/// Log both compile-time and runtime GTK versions
pub fn logVersion() void {
    log.info("GTK version build={} runtime={}", .{
        comptime_version,
        getRuntimeVersion(),
    });
}

/// Verifies that the GTK version is at least the given version.
///
/// This can be run in both a comptime and runtime context. If it is run in a
/// comptime context, it will only check the version in the headers. If it is
/// run in a runtime context, it will check the actual version of the library we
/// are linked against.
///
/// This function should be used in cases where the version check would affect
/// code generation, such as using symbols that are only available beyond a
/// certain version. For checks which only depend on GTK's runtime behavior,
/// use `runtimeAtLeast`.
///
/// This is inlined so that the comptime checks will disable the runtime checks
/// if the comptime checks fail.
pub inline fn atLeast(
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    // If our header has lower versions than the given version,
    // we can return false immediately. This prevents us from
    // compiling against unknown symbols and makes runtime checks
    // very slightly faster.
    if (comptime comptime_version.order(.{
        .major = major,
        .minor = minor,
        .patch = micro,
    }) == .lt) return false;

    // If we're in comptime then we can't check the runtime version.
    if (@inComptime()) return true;

    return runtimeAtLeast(major, minor, micro);
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
    // We use the functions instead of the constants such as c.GTK_MINOR_VERSION
    // because the function gets the actual runtime version.
    const runtime_version = getRuntimeVersion();
    return runtime_version.order(.{
        .major = major,
        .minor = minor,
        .patch = micro,
    }) != .lt;
}

/// Verifies that the GTK version at runtime is before the given version.
pub inline fn runtimeUntil(
    comptime major: u16,
    comptime minor: u16,
    comptime micro: u16,
) bool {
    const runtime_version = getRuntimeVersion();
    return runtime_version.order(.{
        .major = major,
        .minor = minor,
        .patch = micro,
    }) == .lt;
}

test "atLeast" {
    const testing = std.testing;

    const funs = &.{ atLeast, runtimeAtLeast };
    inline for (funs) |fun| {
        try testing.expect(fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));

        try testing.expect(!fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION + 1));
        try testing.expect(!fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION + 1, c.GTK_MICRO_VERSION));
        try testing.expect(!fun(c.GTK_MAJOR_VERSION + 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));

        try testing.expect(fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));
        try testing.expect(fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION + 1, c.GTK_MICRO_VERSION));
        try testing.expect(fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION + 1));

        try testing.expect(fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION - 1, c.GTK_MICRO_VERSION + 1));
    }
}

test "runtimeUntil" {
    const testing = std.testing;

    // This is an array in case we add a comptime variant.
    const funs = &.{runtimeUntil};
    inline for (funs) |fun| {
        try testing.expect(!fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));

        try testing.expect(fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION + 1));
        try testing.expect(fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION + 1, c.GTK_MICRO_VERSION));
        try testing.expect(fun(c.GTK_MAJOR_VERSION + 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));

        try testing.expect(!fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION));
        try testing.expect(!fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION + 1, c.GTK_MICRO_VERSION));
        try testing.expect(!fun(c.GTK_MAJOR_VERSION - 1, c.GTK_MINOR_VERSION, c.GTK_MICRO_VERSION + 1));

        try testing.expect(!fun(c.GTK_MAJOR_VERSION, c.GTK_MINOR_VERSION - 1, c.GTK_MICRO_VERSION + 1));
    }
}
