# Ghostty UI/UX Best Practices for Talkies

This document summarizes architectural patterns and best practices learned from the Ghostty project that should be applied to Talkies Linux.

## Key Architectural Patterns

### 1. **Runtime Abstraction Pattern**
Ghostty uses a clean runtime abstraction in `src/apprt/runtime.zig`:
- Defines enum for different UI backends (GTK, none, etc.)
- Platform-specific defaults based on OS
- Allows compile-time selection of UI runtime

**Apply to Talkies:**
```zig
// linux/src/runtime.zig
pub const Runtime = enum {
    none,      // CLI only
    gtk,       // Full GTK4 UI

    pub fn default(target: std.Target) Runtime {
        return switch (target.os.tag) {
            .linux => .gtk,
            else => .none,
        };
    }
};
```

### 2. **Modular UI Organization**
Ghostty organizes GTK code with clear separation:
```
src/apprt/gtk/
├── App.zig              # Application entry point
├── Surface.zig          # Core surface/window logic
├── class/               # Custom GTK classes
├── ui/                  # Declarative UI definitions
│   ├── 1.0/            # Version 1.0 UI
│   ├── 1.2/            # Version 1.2 UI (breaking changes)
│   └── 1.5/            # Latest version
├── css/                 # Custom styling
├── ext/                 # Extension utilities
└── winproto/            # Window protocol (X11/Wayland)
```

**Apply to Talkies:**
```
linux/src/ui/
├── App.zig              # Main application
├── TrayIcon.zig         # System tray
├── SettingsWindow.zig   # Settings dialog
├── RecordingOverlay.zig # Visual feedback during recording
└── ui/
    └── v1/
        ├── settings.blp # Declarative GTK UI
        └── tray-menu.blp
```

### 3. **Use Blueprint for GTK UI**
Ghostty uses `.blp` files (Blueprint markup) for declarative UI:
- Separates UI definition from logic
- Easier to modify and version
- Compile-time validation

**Example from Ghostty:**
```blp
using Gtk 4.0;
using Adw 1;

Window window {
  title: "Settings";
  default-width: 600;
  default-height: 400;

  Box {
    orientation: vertical;

    HeaderBar {
      title-widget: Label {
        label: "Talkies Settings";
      };
    }
  }
}
```

**Apply to Talkies:**
Create `linux/src/ui/v1/settings.blp` for settings window instead of manual GTK code.

### 4. **zig-gobject for GTK Bindings**
Instead of `@cImport`, use pre-generated bindings:
- Add to `build.zig.zon`: `.gobject` dependency
- Import with `const gtk = @import("gtk");`
- Avoids cImport complexity with GTK headers

**Apply to Talkies:**
```zig
// build.zig.zon
.dependencies = .{
    .gobject = .{
        .url = "https://deps.files.ghostty.org/gobject-2025-11-08-23-1.tar.zst",
        .hash = "gobject-0.3.0-Skun7ANLnwDvEfIpVmohcppXgOvg_I6YOJFmPIsKfXk-",
        .lazy = true,
    },
},
```

### 5. **Platform-Specific Protocol Handling**
Ghostty has `winproto/` for X11/Wayland differences:
- `x11.zig` - X11-specific code
- `wayland.zig` - Wayland-specific code
- `noop.zig` - Fallback/test

**Apply to Talkies:**
```
linux/src/platform/
├── x11.zig      # X11 clipboard, global hotkeys
├── wayland.zig  # Wayland clipboard via wl-copy
└── common.zig   # Shared interfaces
```

### 6. **Logging Strategy**
Ghostty has comprehensive logging:
- Debug logs in Debug builds to stderr
- Production logs to platform-specific sinks (journald on Linux)
- `GHOSTTY_LOG` env var for runtime control
- Scoped logging: `const log = std.log.scoped(.talkies);`

**Apply to Talkies:**
```zig
// linux/src/main.zig
const log = std.log.scoped(.talkies);

pub fn main() !void {
    log.info("Talkies daemon starting", .{});
    log.debug("Config path: {s}", .{cfg_path});
}
```

### 7. **Structured Build System**
Ghostty's `build.zig` patterns:
- Platform detection helper (`src/build/gtk.zig`)
- Conditional compilation based on available libraries
- Separate build steps for different targets

**Apply to Talkies:**
```zig
// linux/build.zig
const gtk_targets = gtk.targets(b);
if (gtk_targets.wayland) {
    exe.root_module.addImport("platform", wayland_module);
} else if (gtk_targets.x11) {
    exe.root_module.addImport("platform", x11_module);
}
```

## UI/UX Best Practices

### 1. **Version Your UI**
Store UI definitions in versioned directories (`ui/1.0/`, `ui/1.2/`):
- Allows breaking changes without affecting users on older GTK versions
- Runtime selection based on detected GTK version
- Clean migration path

### 2. **Minimal Chrome, Maximum Functionality**
Ghostty's UI philosophy:
- Hide complexity by default
- Keyboard shortcuts for power users
- Context menus for discoverability
- Native platform integration (system tray, notifications)

**Apply to Talkies:**
- System tray icon as primary UI
- Right-click menu for settings
- Visual feedback during recording (overlay or notification)
- Keyboard shortcuts (already implemented!)

### 3. **Cross-Platform Consistency**
Maintain consistent behavior across platforms:
- Common Zig core (`src/`)
- Platform-specific adapters (`src/apprt/`)
- Shared configuration format

### 4. **Performance Over Convenience**
Ghostty prioritizes performance:
- Native code over scripting
- Direct system APIs over abstractions
- Compile-time optimization where possible

**Already doing in Talkies:**
- ✅ Native uinput (50x faster than xdotool)
- ✅ Direct PulseAudio API
- ✅ Compile-time icon embedding

### 5. **Developer Experience**
Ghostty provides excellent DX:
- Clear documentation (HACKING.md, AGENTS.md)
- Fast build times (use debug builds by default)
- Good error messages
- Unit tests for all modules

**Apply to Talkies:**
- ✅ Already have good README
- Add HACKING.md with build instructions
- Add unit tests: `zig build test`

## Immediate Action Items for Talkies

### High Priority
1. **Add zig-gobject dependency** to `build.zig.zon`
2. **Create runtime abstraction** for CLI vs GTK builds
3. **Install blueprint-compiler** and create `.blp` UI files
4. **Implement proper logging** with scoped loggers

### Medium Priority
5. **Organize code** into `ui/`, `platform/`, `core/` directories
6. **Add unit tests** for all core modules
7. **Version UI** starting with `ui/v1/`
8. **Create settings window** using Blueprint

### Low Priority (Polish)
9. **Add visual recording overlay** (like Ghostty's command palette)
10. **Implement proper error dialogs** using GTK
11. **Add keyboard shortcut configuration** UI
12. **Create welcome screen** for first-time users

## Code Examples to Study

From Ghostty repository:
- `src/apprt/gtk/App.zig` - Application lifecycle
- `src/apprt/gtk/ui/1.5/window.blp` - Blueprint UI examples
- `src/apprt/gtk/class/application.zig` - Custom GObject classes
- `src/build/gtk.zig` - Build system helpers
- `src/apprt/gtk/winproto/wayland.zig` - Wayland integration

## Resources

- [Ghostty GitHub](https://github.com/ghostty-org/ghostty)
- [zig-gobject](https://github.com/ianprime0509/zig-gobject) - GTK bindings for Zig
- [Blueprint](https://jwestman.pages.gitlab.gnome.org/blueprint-compiler/) - GTK UI markup
- [GTK4 Documentation](https://docs.gtk.org/gtk4/)
- [Agents.md Spec](https://agents.md/) - AI agent guidance format

## Next Steps

1. Review this document with team
2. Decide on implementation priority
3. Start with zig-gobject integration
4. Incrementally adopt patterns

---

*Document created: 2025-12-18*
*Based on: Ghostty main branch @ Dec 2024*
