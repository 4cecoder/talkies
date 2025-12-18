# Ghostty Integration Guide

This document explains the code integrated from the Ghostty project and how to use it in Talkies.

## Overview

We've integrated four key components from Ghostty to improve Talkies' Linux platform support:

1. **Build-time GTK4 Platform Detection** (`src/build/gtk.zig`)
2. **Runtime GTK Version Checking** (`src/ui/gtk_version.zig`)
3. **Runtime Mode Abstraction** (`src/runtime.zig`)
4. **Platform Protocol Detection** (`src/ui/platform.zig`)

All code is properly attributed with MIT license headers. See `THIRD_PARTY_LICENSES.md` for full details.

## Components

### 1. Build-time GTK4 Platform Detection

**File**: `src/build/gtk.zig`

**Purpose**: Detects which windowing protocols (X11/Wayland) your GTK4 installation was compiled with.

**Usage in build.zig**:

```zig
const gtk_build = @import("src/build/gtk.zig");

pub fn build(b: *std.Build) void {
    // Detect GTK4 platform support
    const gtk_targets = gtk_build.targets(b);
    const has_x11 = gtk_targets.x11;
    const has_wayland = gtk_targets.wayland;

    // Use this to conditionally compile platform-specific code
    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", has_x11);
    build_options.addOption(bool, "wayland", has_wayland);
}
```

**Why This Matters**: On some systems, GTK4 might only be compiled with Wayland support (no X11), or vice versa. This lets you:
- Avoid linking against libraries that aren't available
- Enable/disable features based on available backends
- Provide helpful error messages to users

### 2. Runtime GTK Version Checking

**File**: `src/ui/gtk_version.zig`

**Purpose**: Check GTK version at both compile-time and runtime to handle API differences.

**Usage Example**:

```zig
const gtk_version = @import("ui/gtk_version.zig");

pub fn initUI() !void {
    // Log the GTK version
    gtk_version.logVersion();

    // Check if we have GTK 4.10+ for a specific feature
    if (gtk_version.atLeast(4, 10, 0)) {
        // Use newer GTK 4.10+ API
        setupModernUI();
    } else {
        // Fall back to older API
        setupLegacyUI();
    }

    // Runtime-only check (doesn't affect compilation)
    if (gtk_version.runtimeAtLeast(4, 12, 0)) {
        std.log.info("Enabling GTK 4.12+ features", .{});
    }
}
```

**Functions**:
- `comptime_version` - Version from headers (compile-time constant)
- `getRuntimeVersion()` - Actual library version at runtime
- `logVersion()` - Log both versions for debugging
- `atLeast(major, minor, micro)` - Check version (compile-time and runtime aware)
- `runtimeAtLeast(major, minor, micro)` - Runtime check only
- `runtimeUntil(major, minor, micro)` - Check if runtime is before a version

**Why This Matters**: GTK4 is evolving rapidly. Different distributions ship different versions:
- Ubuntu 22.04: GTK 4.6
- Ubuntu 24.04: GTK 4.14
- Arch Linux: Latest GTK 4.x

This lets you safely use newer APIs when available while maintaining compatibility.

### 3. Runtime Mode Abstraction

**File**: `src/runtime.zig`

**Purpose**: Abstract over different UI modes (CLI vs GTK).

**Usage Example**:

```zig
const runtime = @import("runtime.zig");
const build_options = @import("build_options");

pub fn main() !void {
    const current_runtime = if (std.process.args.contains("--cli"))
        runtime.Runtime.cli
    else
        runtime.Runtime.gtk;

    std.log.info("Running in {} mode", .{current_runtime.description()});

    if (current_runtime.isGraphical()) {
        // Initialize GTK, create windows
        try initGTKUI();
    } else {
        // Run in CLI mode
        try runCLI();
    }

    if (current_runtime.supportsTray()) {
        // Initialize system tray
        try initSystemTray();
    }
}
```

**Methods**:
- `Runtime.default(target)` - Get default runtime for a platform
- `description()` - Human-readable name
- `isGraphical()` - Whether this runtime has GUI
- `supportsTray()` - Whether system tray is available

**Why This Matters**: Talkies can run in different modes:
- **CLI mode**: Headless transcription for scripting/servers
- **GTK mode**: Full graphical interface with tray icon

This abstraction makes it easy to share code between modes.

### 4. Platform Protocol Detection

**File**: `src/ui/platform.zig`

**Purpose**: Detect whether the app is running under X11 or Wayland at runtime.

**Usage Example**:

```zig
const platform = @import("ui/platform.zig");

pub fn initHotkeys() !void {
    const proto = platform.Protocol.detect();

    std.log.info("Running on {s} display server", .{proto.name()});

    if (proto.supportsGlobalHotkeys()) {
        // Use X11's XGrabKey for global hotkeys
        try setupX11Hotkeys();
    } else if (proto == .wayland) {
        // Wayland requires different approach
        std.log.warn("Global hotkeys limited on Wayland", .{});
        // Maybe use a compositor-specific protocol or libinput
    }

    if (proto.supportsClipboard()) {
        try initClipboard(proto);
    }
}
```

**Methods**:
- `Protocol.detect()` - Auto-detect current protocol
- `name()` - Get protocol name ("X11", "Wayland", "Unknown")
- `isModern()` - Whether it's Wayland (modern) or X11 (legacy)
- `supportsClipboard()` - Clipboard availability
- `supportsGlobalHotkeys()` - Global hotkey support

**Detection Logic**:
1. Check `WAYLAND_DISPLAY` environment variable
2. Check `XDG_SESSION_TYPE` environment variable
3. Fall back to checking `DISPLAY` for X11
4. Return `.unknown` if none are set

**Why This Matters**: X11 and Wayland have very different APIs:
- **Global Hotkeys**: X11 has XGrabKey, Wayland restricts this for security
- **Clipboard**: Different protocols (X11 selections vs wl_data_device)
- **Window Management**: X11 allows more control, Wayland is more restricted

## Integration Checklist

When using these utilities in new code:

- [ ] **Include License Headers**: All new files using Ghostty patterns should acknowledge the original source
- [ ] **Use build_options**: Check `@import("build_options").x11` and `.wayland` before platform-specific code
- [ ] **Check GTK Version**: Use `gtk_version.atLeast()` before using newer GTK APIs
- [ ] **Detect Protocol**: Use `platform.Protocol.detect()` instead of hardcoding X11 assumptions
- [ ] **Test Both Platforms**: If possible, test on both X11 and Wayland sessions

## Example: Complete Integration

Here's a complete example showing all components working together:

```zig
const std = @import("std");
const runtime = @import("runtime.zig");
const gtk_version = @import("ui/gtk_version.zig");
const platform = @import("ui/platform.zig");
const build_options = @import("build_options");

pub fn main() !void {
    // 1. Determine runtime mode
    const app_runtime = runtime.Runtime.gtk;
    std.log.info("Talkies starting in {} mode", .{app_runtime.description()});

    // 2. Check GTK version
    gtk_version.logVersion();

    if (!gtk_version.atLeast(4, 6, 0)) {
        std.log.err("Talkies requires GTK 4.6 or newer", .{});
        return error.UnsupportedGTKVersion;
    }

    // 3. Detect platform protocol
    const proto = platform.Protocol.detect();
    std.log.info("Display protocol: {s}", .{proto.name()});

    // 4. Initialize based on available features
    if (app_runtime.isGraphical()) {
        try initGTKUI();

        // Only enable global hotkeys on X11
        if (build_options.x11 and proto.supportsGlobalHotkeys()) {
            try setupGlobalHotkeys();
        } else {
            std.log.warn("Global hotkeys not available on {s}", .{proto.name()});
        }

        // Enable system tray
        if (app_runtime.supportsTray()) {
            try initSystemTray();
        }
    }

    // 5. Run main loop
    try runMainLoop();
}
```

## Build Configuration

Your `build.zig` should look like this:

```zig
const std = @import("std");
const gtk_build = @import("src/build/gtk.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Detect GTK4 platform support
    const gtk_targets = gtk_build.targets(b);
    const has_x11 = gtk_targets.x11;
    const has_wayland = gtk_targets.wayland;

    std.debug.print("GTK4 platform support - X11: {}, Wayland: {}\n", .{
        has_x11,
        has_wayland,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Make platform support available at compile-time
    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", has_x11);
    build_options.addOption(bool, "wayland", has_wayland);
    exe_mod.addImport("build_options", build_options.createModule());

    const exe = b.addExecutable(.{
        .name = "talkies",
        .root_module = exe_mod,
    });

    // Only link X11 if available
    if (has_x11) {
        exe.linkSystemLibrary("X11");
    }

    exe.linkSystemLibrary("gtk4");
    exe.linkLibC();

    b.installArtifact(exe);
}
```

## Testing

Run the tests for the new modules:

```bash
cd /home/fource/talkies/linux

# Test GTK version checking
zig test src/ui/gtk_version.zig --pkg-begin gtk4 /usr/include --pkg-end

# Test runtime abstraction
zig test src/runtime.zig

# Test platform detection
zig test src/ui/platform.zig
```

## Troubleshooting

### Build fails with "gtk4 not found"

```bash
# Install GTK4 development files
sudo apt install libgtk-4-dev  # Debian/Ubuntu
sudo dnf install gtk4-devel    # Fedora
sudo pacman -S gtk4            # Arch Linux
```

### "X11: false, Wayland: false" on build

Your GTK4 installation might be broken or pkg-config isn't finding it:

```bash
# Check GTK4 installation
pkg-config --variable=targets gtk4

# Should output: x11 wayland
```

### Platform detection returns "Unknown"

This happens when running without a display server:

```bash
# X11 session
export DISPLAY=:0

# Wayland session
export WAYLAND_DISPLAY=wayland-0
export XDG_SESSION_TYPE=wayland
```

## Credits

All integrated code is from the [Ghostty terminal emulator](https://github.com/ghostty-org/ghostty):
- **Author**: Mitchell Hashimoto (@mitchellh)
- **License**: MIT License
- **Website**: https://ghostty.org

See `THIRD_PARTY_LICENSES.md` for complete license text and attributions.

## Further Reading

- [Ghostty Architecture](https://github.com/ghostty-org/ghostty/blob/main/ARCHITECTURE.md)
- [GTK4 Documentation](https://docs.gtk.org/gtk4/)
- [Wayland vs X11 Comparison](https://wayland.freedesktop.org/)
- [Zig Build System](https://ziglang.org/learn/build-system/)
