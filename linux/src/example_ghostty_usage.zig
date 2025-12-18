// Example: Using Ghostty-derived utilities in Talkies
//
// This file demonstrates how to use the platform detection and runtime
// abstraction utilities extracted from Ghostty. It's not compiled by default,
// but serves as documentation and can be used as a reference.

const std = @import("std");
const runtime = @import("runtime.zig");
const platform = @import("ui/platform.zig");
const gtk_version = @import("ui/gtk_version.zig");
const build_options = @import("build_options");

/// Example 1: Choosing runtime mode
pub fn selectRuntime(cli_requested: bool) runtime.Runtime {
    if (cli_requested) {
        std.log.info("Running in {s} mode", .{runtime.Runtime.cli.description()});
        return runtime.Runtime.cli;
    }

    const app_runtime = runtime.Runtime.gtk;
    std.log.info("Running in {s} mode", .{app_runtime.description()});

    if (app_runtime.supportsTray()) {
        std.log.info("System tray support available", .{});
    }

    return app_runtime;
}

/// Example 2: Platform-aware hotkey initialization
pub fn initHotkeys() !void {
    const proto = platform.Protocol.detect();
    std.log.info("Display protocol: {s}", .{proto.name()});

    // Only enable global hotkeys on X11
    if (!build_options.x11) {
        std.log.warn("X11 support not compiled in, global hotkeys disabled", .{});
        return;
    }

    if (proto != .x11) {
        std.log.warn("Global hotkeys require X11, running on {s}", .{proto.name()});
        if (proto == .wayland) {
            std.log.info("Consider using compositor-specific hotkey bindings", .{});
        }
        return;
    }

    std.log.info("Initializing X11 global hotkeys...", .{});
    // ... actual X11 hotkey setup code would go here
}

/// Example 3: GTK version-aware UI initialization
pub fn initGTKUI() !void {
    // Log version information
    gtk_version.logVersion();

    // Check minimum version
    if (!gtk_version.atLeast(4, 6, 0)) {
        std.log.err("Talkies requires GTK 4.6 or newer", .{});
        std.log.err("Compile-time version: {}", .{gtk_version.comptime_version});
        std.log.err("Runtime version: {}", .{gtk_version.getRuntimeVersion()});
        return error.UnsupportedGTKVersion;
    }

    // Use newer features if available
    if (gtk_version.atLeast(4, 10, 0)) {
        std.log.info("Using GTK 4.10+ enhanced features", .{});
        // Enable features that require GTK 4.10+
    }

    if (gtk_version.runtimeAtLeast(4, 12, 0)) {
        std.log.info("Enabling GTK 4.12+ runtime features", .{});
        // Enable runtime-only features for GTK 4.12+
    }
}

/// Example 4: Platform-aware clipboard handling
pub fn setupClipboard() !void {
    const proto = platform.Protocol.detect();

    if (!proto.supportsClipboard()) {
        std.log.warn("Clipboard not available (unknown protocol)", .{});
        return error.ClipboardUnavailable;
    }

    std.log.info("Setting up clipboard for {s}", .{proto.name()});

    switch (proto) {
        .x11 => {
            if (build_options.x11) {
                std.log.info("Using X11 selections API", .{});
                // ... X11-specific clipboard code
            } else {
                std.log.err("X11 support not compiled in", .{});
                return error.X11NotAvailable;
            }
        },
        .wayland => {
            if (build_options.wayland) {
                std.log.info("Using Wayland data device protocol", .{});
                // ... Wayland-specific clipboard code
            } else {
                std.log.err("Wayland support not compiled in", .{});
                return error.WaylandNotAvailable;
            }
        },
        .unknown => unreachable, // Already checked above
    }
}

/// Example 5: Feature detection and graceful degradation
pub const Features = struct {
    graphical_ui: bool,
    system_tray: bool,
    global_hotkeys: bool,
    clipboard: bool,
    modern_compositor: bool,
};

pub fn detectFeatures(app_runtime: runtime.Runtime) Features {
    const proto = platform.Protocol.detect();

    return .{
        .graphical_ui = app_runtime.isGraphical(),
        .system_tray = app_runtime.supportsTray(),
        .global_hotkeys = build_options.x11 and proto.supportsGlobalHotkeys(),
        .clipboard = proto.supportsClipboard(),
        .modern_compositor = proto.isModern(),
    };
}

pub fn printFeatures(features: Features) void {
    std.log.info("Talkies Feature Detection:", .{});
    std.log.info("  Graphical UI: {}", .{features.graphical_ui});
    std.log.info("  System Tray: {}", .{features.system_tray});
    std.log.info("  Global Hotkeys: {}", .{features.global_hotkeys});
    std.log.info("  Clipboard: {}", .{features.clipboard});
    std.log.info("  Modern Compositor: {}", .{features.modern_compositor});
}

/// Example main function showing complete integration
pub fn exampleMain() !void {
    std.log.info("Talkies starting up...", .{});
    std.log.info("", .{});

    // 1. Determine runtime
    const cli_mode = false; // Would be parsed from args
    const app_runtime = selectRuntime(cli_mode);
    std.log.info("", .{});

    // 2. Detect available features
    const features = detectFeatures(app_runtime);
    printFeatures(features);
    std.log.info("", .{});

    // 3. Initialize based on runtime
    if (app_runtime.isGraphical()) {
        try initGTKUI();
        std.log.info("", .{});
    }

    // 4. Set up optional features
    if (features.global_hotkeys) {
        try initHotkeys();
    } else {
        std.log.info("Global hotkeys unavailable, using app-level hotkeys only", .{});
    }
    std.log.info("", .{});

    if (features.clipboard) {
        try setupClipboard();
    } else {
        std.log.warn("Clipboard unavailable", .{});
    }
    std.log.info("", .{});

    std.log.info("Talkies initialization complete!", .{});
}

// This file is for documentation only - uncomment to make it a standalone example
// pub fn main() !void {
//     try exampleMain();
// }

test "feature detection" {
    const features_cli = detectFeatures(runtime.Runtime.cli);
    try std.testing.expect(!features_cli.graphical_ui);
    try std.testing.expect(!features_cli.system_tray);

    const features_gtk = detectFeatures(runtime.Runtime.gtk);
    try std.testing.expect(features_gtk.graphical_ui);
    try std.testing.expect(features_gtk.system_tray);
}
