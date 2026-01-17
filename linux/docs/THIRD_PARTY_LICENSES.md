# Third-Party Licenses

This document lists third-party code included in the Talkies Linux project, along with their licenses and attributions.

## Ghostty Project

The following files are derived from the [Ghostty terminal emulator](https://github.com/ghostty-org/ghostty) project:

### Files Copied/Adapted

1. **src/build/gtk.zig**
   - **Original Source**: https://github.com/ghostty-org/ghostty/blob/main/src/build/gtk.zig
   - **Purpose**: Build-time detection of GTK4 platform support (X11/Wayland)
   - **Modifications**: None (direct copy)
   - **License**: MIT License (see below)

2. **src/ui/gtk_version.zig**
   - **Original Source**: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/gtk/gtk_version.zig
   - **Purpose**: Runtime GTK4 version detection and compatibility checking
   - **Modifications**:
     - Simplified to use direct GTK C API instead of Zig GTK bindings
     - Removed dependency on external GTK bindings package
     - Kept core version checking logic intact
   - **License**: MIT License (see below)

3. **src/runtime.zig**
   - **Original Source**: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/runtime.zig
   - **Purpose**: Runtime mode abstraction (CLI vs GTK)
   - **Modifications**:
     - Simplified to only support CLI and GTK modes (removed macOS-specific features)
     - Adapted for Talkies' voice transcription use case vs Ghostty's terminal emulator
     - Renamed from "apprt" (app runtime) to "runtime" for simplicity
     - Added helper methods: `description()`, `isGraphical()`, `supportsTray()`
   - **License**: MIT License (see below)

4. **src/ui/platform.zig**
   - **Original Source**: https://github.com/ghostty-org/ghostty/blob/main/src/apprt/gtk/winproto.zig
   - **Purpose**: Linux windowing protocol detection (X11 vs Wayland)
   - **Modifications**:
     - Heavily simplified - removed GDK/GTK windowing abstractions
     - Focused on platform detection only (X11 vs Wayland)
     - Removed window-specific state management (Talkies uses simpler UI)
     - Kept protocol enumeration pattern from Ghostty
     - Added helper methods: `name()`, `isModern()`, `supportsClipboard()`, `supportsGlobalHotkeys()`
   - **License**: MIT License (see below)

### Ghostty License

```
MIT License

Copyright (c) 2024 Mitchell Hashimoto, Ghostty contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### Why Ghostty Code?

Ghostty is a high-quality, modern terminal emulator built with Zig and GTK4 for Linux. The project demonstrates excellent practices for:

- **Platform Detection**: Robust X11/Wayland detection at both build-time and runtime
- **GTK Version Handling**: Safe handling of GTK version differences across distributions
- **Runtime Abstraction**: Clean separation between CLI and GUI modes
- **Code Quality**: Well-tested, documented, and production-ready

We've adapted these components for Talkies' voice transcription use case, simplifying where appropriate and maintaining compatibility with Talkies' architecture.

### Attribution

We are grateful to Mitchell Hashimoto and the Ghostty contributors for releasing their work under the permissive MIT License, enabling us to build upon their excellent foundation.

**Ghostty Project**: https://github.com/ghostty-org/ghostty
**Ghostty Website**: https://ghostty.org
**Author**: Mitchell Hashimoto (@mitchellh)

## zig-gobject (Pre-Built Bindings) - CURRENTLY DISABLED

**Source**: [ghostty-org/zig-gobject](https://github.com/ghostty-org/zig-gobject)
**Distributed via**: https://deps.files.ghostty.org/gobject-2025-11-08-23-1.tar.zst

**Status**: ⚠️ **BLOCKED - Zig 0.16.0 Incompatibility**

The pre-built bindings are built for Zig 0.15.2 and use the `@Type` builtin which was removed in Zig 0.16.0. Talkies Linux currently runs on Zig 0.16.0-dev.1484, making these bindings incompatible.

**Intended Purpose**: Pre-generated GTK/GObject bindings for Zig, providing clean Zig APIs for GTK4, GLib, GObject, Gdk, and Gio.

**Intended Modules** (when compatibility is restored):
- gtk4 (imported as `@import("gtk")`)
- gdk4 (imported as `@import("gdk")`)
- glib2 (imported as `@import("glib")`)
- gobject2 (imported as `@import("gobject")`)
- gio2 (imported as `@import("gio")`)

**License**: MIT License (same as Ghostty)

**Attribution**:
- Original zig-gobject tool: Ian Johnson (@ianprime0509)
- Pre-built artifact generation: Mitchell Hashimoto and Ghostty contributors
- Repository: https://github.com/ghostty-org/zig-gobject

**Resolution Status**: Awaiting Ghostty's Zig 0.16 migration. See `docs/ZIG_016_GTK_BLOCKER.md` for details and workarounds.

**Impact**: GTK features (settings window, system tray, visual overlay) are temporarily disabled. All core CLI functionality remains fully operational.

---

*Last Updated: 2025-12-18*
