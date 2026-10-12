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
    addCImports(b, target, optimize, exe_mod);

    const exe = b.addExecutable(.{
        .name = "talkies",
        .root_module = exe_mod,
    });

    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", has_x11);
    build_options.addOption(bool, "wayland", has_wayland);
    configureNativeModule(b, exe_mod, has_x11, build_options);

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
    addCImports(b, target, optimize, test_mod);

    configureNativeModule(b, test_mod, has_x11, build_options);
    const unit_tests = b.addTest(.{ .root_module = test_mod });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

/// C sources, system libraries and include paths shared by the app and tests.
fn configureNativeModule(b: *std.Build, module: *std.Build.Module, has_x11: bool, build_options: *std.Build.Step.Options) void {
    module.addImport("build_options", build_options.createModule());

    const c_flags: []const []const u8 = if (has_x11)
        &.{ "-std=c11", "-D_GNU_SOURCE", "-DTALKIES_HAVE_X11" }
    else
        &.{ "-std=c11", "-D_GNU_SOURCE" };
    const c_sources = [_][]const u8{
        "src/yap_window_gtk.c",
        "src/daemon_status_gtk.c",
        "src/hud_gtk.c",
        "src/settings_gtk.c",
        "src/tray_sni.c",
        "src/s1_runtime.c",
    };
    for (c_sources) |source| {
        module.addCSourceFile(.{ .file = b.path(source), .flags = c_flags });
    }

    module.linkSystemLibrary("pulse-simple", .{});
    module.linkSystemLibrary("pulse", .{});
    module.linkSystemLibrary("whisper", .{});
    module.linkSystemLibrary("llama", .{});
    module.linkSystemLibrary("sqlite3", .{}); // YAP session management

    // libfvad (WebRTC VAD) - vendored static library
    module.addObjectFile(b.path("vendor/libfvad/lib/libfvad.a"));
    module.addIncludePath(b.path("vendor/libfvad/include"));

    // Only link X11 if GTK was built with X11 support
    if (has_x11) module.linkSystemLibrary("X11", .{});

    module.linkSystemLibrary("dbus-1", .{}); // System tray (StatusNotifierItem)
    module.linkSystemLibrary("gtk4", .{}); // HUD, settings, status and YAP windows
    module.linkSystemLibrary("glib-2.0", .{});
    module.linkSystemLibrary("gobject-2.0", .{});
    module.linkSystemLibrary("gio-2.0", .{});
    module.link_libc = true;

    // libwhisper/libggml aren't packaged by any Linux distro (see
    // linux/docs/DEPENDENCIES.md). Release packaging bundles those .so files
    // in a lib/ directory next to the binary; $ORIGIN is resolved at runtime.
    module.addRPathSpecial("$ORIGIN/lib");

    module.addIncludePath(.{ .cwd_relative = "/usr/include" });
    module.addIncludePath(b.path("src"));
    const include_dirs = [_][]const u8{
        "/usr/include/gtk-4.0",
        "/usr/include/pango-1.0",
        "/usr/include/harfbuzz",
        "/usr/include/glib-2.0",
        "/usr/lib64/glib-2.0/include",
        "/usr/include/cairo",
        "/usr/include/gdk-pixbuf-2.0",
        "/usr/include/graphene-1.0",
        "/usr/lib64/graphene-1.0/include",
        "/usr/include/dbus-1.0",
        "/usr/lib64/dbus-1.0/include",
    };
    for (include_dirs) |dir| module.addIncludePath(.{ .cwd_relative = dir });
    const multiarch_dir = b.fmt("/usr/lib/{s}-linux-gnu", .{@tagName(module.resolved_target.?.result.cpu.arch)});
    module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/glib-2.0/include", .{multiarch_dir}) });
    module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/graphene-1.0/include", .{multiarch_dir}) });
    module.addIncludePath(.{ .cwd_relative = b.fmt("{s}/dbus-1.0/include", .{multiarch_dir}) });
}

fn addCImports(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Optimize,
    module: *std.Build.Module,
) void {
    addCImport(b, target, optimize, module, "c_audio", "audio.h", &.{ "pulse-simple", "pulse" });
    addCImport(b, target, optimize, module, "c_daemon_status", "daemon_status.h", &.{});
    addCImport(b, target, optimize, module, "c_hotkey", "hotkey.h", &.{"X11"});
    addCImport(b, target, optimize, module, "c_input", "input.h", &.{});
    addCImport(b, target, optimize, module, "c_sqlite3", "sqlite3.h", &.{"sqlite3"});
    addCImport(b, target, optimize, module, "c_s1_runtime", "s1_runtime.h", &.{});
    addCImport(b, target, optimize, module, "c_tray", "tray.h", &.{});
    addCImport(b, target, optimize, module, "c_hud", "hud.h", &.{});
    addCImport(b, target, optimize, module, "c_settings", "settings.h", &.{});
    addCImport(b, target, optimize, module, "c_vad", "vad.h", &.{});
    addCImport(b, target, optimize, module, "c_whisper", "whisper.h", &.{});
    addCImport(b, target, optimize, module, "c_yap_window", "yap_window.h", &.{});
}

fn addCImport(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Optimize,
    module: *std.Build.Module,
    name: []const u8,
    header: []const u8,
    libraries: []const []const u8,
) void {
    const translation = b.addTranslateC(.{
        .root_source_file = b.path(b.fmt("src/c_headers/{s}", .{header})),
        .target = target,
        .optimize = optimize,
    });
    translation.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    translation.addSystemIncludePath(.{ .cwd_relative = "/usr/local/include" });
    translation.addIncludePath(b.path("src"));
    translation.addIncludePath(b.path("vendor/libfvad/include"));
    for (libraries) |library| {
        translation.linkSystemLibrary(library, .{});
    }
    module.addImport(name, translation.createModule());
}
