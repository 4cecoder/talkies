const std = @import("std");

pub const Targets = struct {
    x11: bool,
    wayland: bool,
};

/// Detect which GTK4 backends the build host actually has available.
///
/// This checks for the backend-specific GDK headers that a GTK4 -dev
/// package only installs when it was built with that backend enabled
/// (gdk/x11/gdkx.h, gdk/wayland/gdkwayland.h) — a standard Debian/Ubuntu
/// `libgtk-4-dev` install ships both. It deliberately avoids spawning a
/// subprocess (e.g. `pkg-config --variable=targets gtk4`, which is the
/// more "official" way GTK4 exposes this) because std.process's API
/// surface has been in flux across recent Zig releases (see the I/O
/// interface work in 0.16), and this repo intentionally tracks Zig
/// master — a stale process-spawning guess is a worse failure mode here
/// than a slightly more conservative header check.
///
/// NOTE: this file did not exist anywhere in git history despite being
/// @import'd by build.zig — it was reconstructed from scratch. Review
/// this against whatever the original detection logic actually did, if
/// that's recoverable, and adjust the header paths below if your
/// distro's GTK4 headers don't live under /usr/include/gtk-4.0 (see the
/// "Workaround Ubuntu multiarch include paths" step in
/// .github/workflows/ci.yml and release.yml for the same class of
/// distro-layout assumption elsewhere in this build).
pub fn targets(b: *std.Build) Targets {
    _ = b;
    return .{
        .x11 = headerExists("/usr/include/gtk-4.0/gdk/x11/gdkx.h"),
        .wayland = headerExists("/usr/include/gtk-4.0/gdk/wayland/gdkwayland.h"),
    };
}

fn headerExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}
