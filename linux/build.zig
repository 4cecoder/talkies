const std = @import("std");
const gtk_build = @import("src/build/gtk.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Detect GTK4 platform support (X11/Wayland)
    const gtk_targets = gtk_build.targets(b);
    const has_x11 = gtk_targets.x11;
    const has_wayland = gtk_targets.wayland;

    // Log platform support for debugging
    std.debug.print("GTK4 platform support - X11: {}, Wayland: {}\n", .{ has_x11, has_wayland });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "talkies",
        .root_module = exe_mod,
    });

    // Add C source files for GTK wrappers
    // (addCSourceFile moved from Step.Compile to Module upstream)
    exe_mod.addCSourceFile(.{
        .file = b.path("src/yap_window_gtk.c"),
        .flags = &.{"-std=c11"},
    });
    exe_mod.addCSourceFile(.{
        .file = b.path("src/daemon_status_gtk.c"),
        .flags = &.{"-std=c11"},
    });

    // Add build options for runtime platform detection
    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", has_x11);
    build_options.addOption(bool, "wayland", has_wayland);
    exe_mod.addImport("build_options", build_options.createModule());

    // GTK/GObject bindings - DISABLED temporarily
    // Ghostty's pre-built bindings use Zig 0.15.2 APIs (@Type builtin)
    // Zig 0.16.0 removed @Type, causing compilation errors
    // Re-enable when Ghostty updates bindings for Zig 0.16 compatibility
    // const gobject_ = b.lazyDependency("gobject", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // if (gobject_) |gobject| {
    //     const gobject_imports = .{
    //         .{ "gtk", "gtk4" },
    //         .{ "gdk", "gdk4" },
    //         .{ "glib", "glib2" },
    //         .{ "gobject", "gobject2" },
    //         .{ "gio", "gio2" },
    //     };
    //     inline for (gobject_imports) |import| {
    //         const name, const module = import;
    //         exe_mod.addImport(name, gobject.module(module));
    //     }
    //     std.debug.print("GTK bindings loaded from Ghostty artifact\n", .{});
    // }

    // Link system libraries
    // (linkSystemLibrary/addObjectFile/addIncludePath/addRPath/linkLibC all
    // moved from Step.Compile to Module upstream; linkSystemLibrary also
    // gained a mandatory options param, Zig has no default arguments)
    exe_mod.linkSystemLibrary("pulse-simple", .{});
    exe_mod.linkSystemLibrary("pulse", .{});
    exe_mod.linkSystemLibrary("whisper", .{});
    exe_mod.linkSystemLibrary("sqlite3", .{}); // For YAP session management

    // Link libfvad (WebRTC VAD) - vendored static library
    exe_mod.addObjectFile(b.path("vendor/libfvad/lib/libfvad.a"));
    exe_mod.addIncludePath(b.path("vendor/libfvad/include"));

    // Only link X11 if GTK was built with X11 support
    if (has_x11) {
        exe_mod.linkSystemLibrary("X11", .{});
    }

    exe_mod.linkSystemLibrary("dbus-1", .{}); // For system tray
    exe_mod.linkSystemLibrary("gtk-4", .{}); // For settings UI
    exe_mod.linkSystemLibrary("glib-2.0", .{}); // For GLib functions in GTK wrappers
    exe_mod.linkSystemLibrary("gobject-2.0", .{}); // For GObject functions in GTK wrappers
    exe_mod.link_libc = true;

    // libwhisper/libggml aren't packaged by any Linux distro (see
    // linux/docs/DEPENDENCIES.md — every distro builds them from source).
    // Release packaging bundles those .so files next to the binary in a
    // lib/ directory; this rpath lets the dynamic linker find them there
    // without needing them installed system-wide. $ORIGIN is a literal
    // linker token (resolved at runtime, relative to the binary's own
    // location), not a build-time filesystem path.
    exe_mod.addRPath(.{ .cwd_relative = "$ORIGIN/lib" });

    // Add include paths for whisper.h and GTK4
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include" });
    exe_mod.addIncludePath(b.path("src")); // For yap_window_gtk.h
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/gtk-4.0" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/pango-1.0" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/glib-2.0" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/lib64/glib-2.0/include" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/cairo" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/gdk-pixbuf-2.0" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/include/graphene-1.0" });
    exe_mod.addIncludePath(.{ .cwd_relative = "/usr/lib64/graphene-1.0/include" });

    b.installArtifact(exe);

    // Run command
    // (b.args, which forwarded `zig build run -- extra args`, was removed
    // upstream with no direct replacement; dropped since it's a local-dev
    // convenience only, not exercised by CI)
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // GTK overlay runner
    // (b.pathFromRoot was removed upstream; addFileArg is the current way
    // to pass a build-root-relative path to a spawned command)
    const overlay_cmd = b.addSystemCommand(&[_][]const u8{"python3"});
    overlay_cmd.addFileArg(b.path("talkies-overlay-gtk"));
    const overlay_step = b.step("overlay", "Run the GTK overlay");
    overlay_step.dependOn(&overlay_cmd.step);

    // Cleanup command to kill stuck processes and free ports
    const cleanup_cmd = b.addSystemCommand(&[_][]const u8{"bash"});
    cleanup_cmd.addFileArg(b.path("scripts/cleanup.sh"));
    const cleanup_step = b.step("cleanup", "Kill stuck talkies processes and free ports");
    cleanup_step.dependOn(&cleanup_cmd.step);

    // Tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options to test module
    test_mod.addImport("build_options", build_options.createModule());

    const unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    // Link same libraries for tests
    test_mod.linkSystemLibrary("pulse-simple", .{});
    test_mod.linkSystemLibrary("pulse", .{});
    test_mod.linkSystemLibrary("whisper", .{});
    test_mod.linkSystemLibrary("sqlite3", .{});

    // Link libfvad for tests
    test_mod.addObjectFile(b.path("vendor/libfvad/lib/libfvad.a"));
    test_mod.addIncludePath(b.path("vendor/libfvad/include"));

    // Only link X11 if GTK was built with X11 support
    if (has_x11) {
        test_mod.linkSystemLibrary("X11", .{});
    }

    test_mod.linkSystemLibrary("dbus-1", .{});
    test_mod.linkSystemLibrary("gtk-4", .{});
    test_mod.link_libc = true;
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/gtk-4.0" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/pango-1.0" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/glib-2.0" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/lib64/glib-2.0/include" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/cairo" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/gdk-pixbuf-2.0" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/include/graphene-1.0" });
    test_mod.addIncludePath(.{ .cwd_relative = "/usr/lib64/graphene-1.0/include" });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
