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

    // Add build options for runtime platform detection
    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", has_x11);
    build_options.addOption(bool, "wayland", has_wayland);
    exe_mod.addImport("build_options", build_options.createModule());

    // Add GTK/GObject bindings from Ghostty's pre-built artifact
    // Pattern learned from Ghostty's src/build/SharedDeps.zig
    const gobject_ = b.lazyDependency("gobject", .{
        .target = target,
        .optimize = optimize,
    });
    if (gobject_) |gobject| {
        // Map user-friendly import names to actual module names in the artifact
        const gobject_imports = .{
            .{ "gtk", "gtk4" },
            .{ "gdk", "gdk4" },
            .{ "glib", "glib2" },
            .{ "gobject", "gobject2" },
            .{ "gio", "gio2" },
        };
        inline for (gobject_imports) |import| {
            const name, const module = import;
            exe_mod.addImport(name, gobject.module(module));
        }
        std.debug.print("GTK bindings loaded from Ghostty artifact\n", .{});
    }

    // Link system libraries
    exe.linkSystemLibrary("pulse-simple");
    exe.linkSystemLibrary("pulse");
    exe.linkSystemLibrary("whisper");

    // Only link X11 if GTK was built with X11 support
    if (has_x11) {
        exe.linkSystemLibrary("X11");
    }

    exe.linkSystemLibrary("dbus-1"); // For system tray
    exe.linkSystemLibrary("gtk-4"); // For settings UI
    exe.linkLibC();

    // Add include path for whisper.h
    exe.addIncludePath(.{ .cwd_relative = "/usr/include" });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

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
    unit_tests.linkSystemLibrary("pulse-simple");
    unit_tests.linkSystemLibrary("pulse");
    unit_tests.linkSystemLibrary("whisper");

    // Only link X11 if GTK was built with X11 support
    if (has_x11) {
        unit_tests.linkSystemLibrary("X11");
    }

    unit_tests.linkSystemLibrary("dbus-1");
    unit_tests.linkSystemLibrary("gtk-4");
    unit_tests.linkLibC();
    unit_tests.addIncludePath(.{ .cwd_relative = "/usr/include" });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
