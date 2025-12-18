# Custom zig-gobject Bindings Strategy

**Date**: 2025-12-18
**Decision**: Generate our own GTK/GObject bindings instead of using Ghostty's pre-built artifacts

## Why Custom Bindings?

### Problem with Ghostty's Pre-Built Bindings
1. **Module names unclear** - Ghostty's `.tar.zst` artifact doesn't expose modules named `gtk`, `glib`, etc.
2. **Zig version compatibility** - Pre-built for specific Zig version (0.14.1), we're on 0.16.0
3. **Unnecessary libraries** - Ghostty includes Nautilus, Panel, GExiv2, etc. that we don't need
4. **Black box** - No control over what's generated or how

### Benefits of Custom Generation
1. **Full control** - Only generate bindings for libraries we actually use
2. **Future-proof** - Can regenerate for new Zig versions
3. **Smaller** - Only GTK4, GLib, GObject, Gdk - no bloat
4. **Transparent** - Build process is visible and maintainable

## Architecture

### Build-Time Generation

```
Build Phase:
  ├─ Step 1: Find system .gir files (GIR_PATH)
  ├─ Step 2: Run zig-gobject translate-gir
  ├─ Step 3: Generate bindings/ directory
  └─ Step 4: Add as modules to exe_mod

Runtime:
  └─ Import modules: @import("gtk"), @import("glib"), etc.
```

### Libraries We Generate

**Minimal set for Talkies**:
- `GLib-2.0` - Core GLib utilities
- `GObject-2.0` - Object type system
- `Gio-2.0` - I/O and networking
- `Gdk-4.0` - GTK4 drawing kit
- `Gtk-4.0` - GTK4 widgets

**Not needed** (unlike Ghostty):
- `Adw-1` - Libadwaita (we use vanilla GTK)
- `GdkWayland-4.0`, `GdkX11-4.0` - Backend-specific (not needed for widgets)
- `Nautilus-4.1` - File manager integration
- `Panel-1` - GNOME panel
- `GExiv2-0.10` - Image metadata
- `Rsvg-2.0` - SVG rendering
- `Xdp-1.0`, `XdpGtk4-1.0` - XDG portals

## Implementation

### build.zig Integration

```zig
// Get zig-gobject codegen dependency
const gobject_codegen_dep = b.dependency("gobject_codegen", .{});
const translate_gir_exe = gobject_codegen_dep.artifact("translate-gir");

// Run code generation
const translate_gir_run = b.addRunArtifact(translate_gir_exe);
const bindings = translate_gir_run.addPrefixedOutputDirectoryArg("--output-dir=", "bindings");

// Specify libraries to generate
translate_gir_run.addArg("GLib-2.0");
translate_gir_run.addArg("GObject-2.0");
translate_gir_run.addArg("Gio-2.0");
translate_gir_run.addArg("Gdk-4.0");
translate_gir_run.addArg("Gtk-4.0");

// Set GIR_PATH to system .gir files
// Auto-detect: /usr/share/gir-1.0, /usr/local/share/gir-1.0, etc.

// Add generated bindings as modules
exe_mod.addAnonymousImport("gtk", .{ .root_source_file = bindings.path(b, "gtk.zig") });
exe_mod.addAnonymousImport("glib", .{ .root_source_file = bindings.path(b, "glib.zig") });
// ... etc
```

### System .gir File Locations

**Typical paths on Linux**:
- Gentoo: `/usr/share/gir-1.0/`
- Ubuntu/Debian: `/usr/share/gir-1.0/`
- Fedora: `/usr/share/gir-1.0/`
- Arch: `/usr/share/gir-1.0/`

**Required .gir files**:
```
/usr/share/gir-1.0/GLib-2.0.gir
/usr/share/gir-1.0/GObject-2.0.gir
/usr/share/gir-1.0/Gio-2.0.gir
/usr/share/gir-1.0/Gdk-4.0.gir
/usr/share/gir-1.0/Gtk-4.0.gir
```

## Comparison: Ghostty vs Talkies

| Aspect | Ghostty | Talkies (Custom) |
|--------|---------|------------------|
| **Approach** | Pre-built .tar.zst | Build-time generation |
| **Libraries** | 15+ (Adw, Nautilus, Panel, etc.) | 5 (GLib, GObject, Gio, Gdk, Gtk) |
| **Size** | ~10-20MB compressed | ~2-5MB generated |
| **Control** | None (black box) | Full (can modify) |
| **Zig Version** | Tied to 0.14.1 | Generates for current (0.16.0) |
| **Flexibility** | Fixed set | Can add/remove libraries |
| **Build Speed** | Fast (pre-built) | Slower (generation) but cached |

## Migration from @cImport

**Before** (settings_ui.zig):
```zig
const c = @cImport({
    @cInclude("gtk/gtk.h");  // Fails due to complex GTK headers
});

self.window = c.gtk_window_new();
c.gtk_window_set_title(win, "Settings");
```

**After** (with custom bindings):
```zig
const gtk = @import("gtk");

self.window = try gtk.Window.new();
self.window.?.setTitle("Settings");
```

## Next Steps

1. ✅ Add `gobject_codegen` dependency to `build.zig.zon`
2. 🚧 Detect system GIR_PATH in build.zig
3. 🚧 Integrate translate-gir into build pipeline
4. 🚧 Generate bindings for 5 core libraries
5. 🚧 Update tray.zig and settings_ui.zig to use generated bindings
6. 🚧 Test build and runtime functionality
7. 🚧 Document for other contributors

## License Attribution

**zig-gobject (upstream)**:
- **Author**: Ian Johnson (@ianprime0509)
- **License**: MIT
- **Repository**: https://github.com/ianprime0509/zig-gobject
- **Purpose**: Code generation tool only (not distributed with Talkies)

Generated bindings are our own code, but we'll add attribution to `THIRD_PARTY_LICENSES.md` for the tool used.

---

*This strategy follows Ghostty's philosophy of using proven tools, but adapted for Talkies' specific needs.*
