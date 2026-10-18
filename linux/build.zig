//! Talkies for Linux - build graph split by volatility.
//!
//!   vendor (lowest)  libwhisper / libggml* / libllama      bundled in lib/
//!                    CrispASR + its own ggml                bundled in lib/crispasr/
//!   native           libtalkies-native.so  (S1-mini llama runtime and the
//!                    CrispASR loader for Phonon-2, C ABI)
//!   core             src/core   pure Zig helpers           \
//!   engine           src/engine audio/VAD/whisper/IO        } linked into bin/talkies
//!   app (highest)    src/app    daemon, config, prompts    /
//!   ui               libtalkies-ui.so  (GTK4/D-Bus windows, C ABI)
//!
//! Module imports only point down the stack (app -> engine -> core), which
//! the build enforces: `core` has no imports, `engine` sees only `core`.
//! The C shared libraries keep GTK/D-Bus and llama.cpp out of the app
//! binary's direct link line, so each tier can be rebuilt and shipped on
//! its own cadence (see scripts/install.sh).

const std = @import("std");
const gtk_build = @import("src/build/gtk.zig");

const Ctx = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: ?std.builtin.Optimize,
    has_x11: bool,
    /// Install prefix of a private whisper.cpp/llama.cpp build (from-source
    /// packaging, e.g. the Gentoo ebuild); null = system / pkg-config.
    native_prefix: ?[]const u8,
};

/// Libraries of the pinned CrispASR release archive, installed under their
/// sonames (the archive's symlinks are not carried over). Optional ones are
/// absent on some architectures.
const crispasr_libraries = [_]struct { file: []const u8, soname: []const u8, optional: bool = false }{
    .{ .file = "libcrispasr.so.0.8.43", .soname = "libcrispasr.so.1" },
    .{ .file = "libggml.so.0.26.0", .soname = "libggml.so.0" },
    .{ .file = "libggml-base.so.0.26.0", .soname = "libggml-base.so.0" },
    .{ .file = "libggml-cpu.so.0.26.0", .soname = "libggml-cpu.so.0" },
    .{ .file = "libopenblas.so.0", .soname = "libopenblas.so.0" },
    .{ .file = "libgfortran.so.5", .soname = "libgfortran.so.5" },
    .{ .file = "libgomp.so.1", .soname = "libgomp.so.1" },
    .{ .file = "libquadmath.so.0", .soname = "libquadmath.so.0", .optional = true },
};

pub fn build(b: *std.Build) void {
    const gtk_targets = gtk_build.targets(b);
    const ctx: Ctx = .{
        .b = b,
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .has_x11 = gtk_targets.x11,
        .native_prefix = b.option([]const u8, "native-prefix", "Prefix holding whisper.cpp/llama.cpp headers and libraries"),
    };

    const build_options = b.addOptions();
    build_options.addOption(bool, "x11", gtk_targets.x11);
    build_options.addOption(bool, "wayland", gtk_targets.wayland);
    // Release builds pass -Dversion=X.Y.Z (packaging/shared/version.txt).
    build_options.addOption([]const u8, "version", b.option([]const u8, "version", "Talkies version string") orelse "dev");
    // Release CI also records what it built, so the updater can tell rolling
    // `latest` builds of the same version apart (src/app/updater.zig).
    build_options.addOption([]const u8, "commit", b.option([]const u8, "commit", "Git commit this build is made from") orelse "");
    build_options.addOption([]const u8, "channel", b.option([]const u8, "channel", "Release label: latest, vX.Y.Z or ci-N (empty for distro builds)") orelse "");

    // --- C shared libraries -------------------------------------------
    const native_lib = addNativeLib(ctx);
    const ui_lib = addUiLib(ctx);
    b.installArtifact(native_lib);
    b.installArtifact(ui_lib);
    if (b.option(bool, "crispasr", "Bundle the pinned CrispASR runtime for Phonon-2 into lib/crispasr (default: on for Linux x86_64/aarch64)") orelse true) {
        installCrispAsr(ctx);
    }
    // Themed tray icons (KDE ColorScheme / GTK symbolic), found via IconThemePath.
    b.installDirectory(.{ .source_dir = b.path("assets/icons"), .install_dir = .prefix, .install_subdir = "share/icons" });

    // --- Zig layers -----------------------------------------------------
    const core = addCoreModule(ctx);
    const engine = addEngineModule(ctx, core, native_lib);
    const app = addAppModule(ctx, core, engine, ui_lib, build_options);

    const exe = b.addExecutable(.{ .name = "talkies", .root_module = app });
    b.installArtifact(exe);
    // Shipped artifacts resolve libraries via $ORIGIN only. Zig would
    // otherwise add an RPATH for every -L directory (e.g. -Dnative-prefix,
    // a distro build root) that does not exist on the user's machine.
    for ([_]*std.Build.Step.Compile{ native_lib, ui_lib, exe }) |artifact| artifact.each_lib_rpath = false;

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    b.step("run", "Run the app").dependOn(&run_cmd.step);

    const overlay_cmd = b.addSystemCommand(&.{"python3"});
    overlay_cmd.addFileArg(b.path("talkies-overlay-gtk"));
    b.step("overlay", "Run the GTK overlay").dependOn(&overlay_cmd.step);

    const cleanup_cmd = b.addSystemCommand(&.{"bash"});
    cleanup_cmd.addFileArg(b.path("scripts/cleanup.sh"));
    b.step("cleanup", "Kill stuck talkies processes and free ports").dependOn(&cleanup_cmd.step);

    // --- Tests, one step per layer ----------------------------------------
    // Fresh module instances so each step runs exactly that layer's tests;
    // test-core needs no system libraries at all.
    const test_step = b.step("test", "Run all unit tests");
    const layers = .{
        .{ "test-core", "Run core-layer tests (no system deps)", addCoreModule(ctx) },
        .{ "test-engine", "Run engine-layer tests", addEngineModule(ctx, core, native_lib) },
        .{ "test-app", "Run app-layer tests", addAppModule(ctx, core, engine, ui_lib, build_options) },
    };
    inline for (layers) |layer| {
        const name, const description, const module = layer;
        // Test binaries never ship: point them straight at the freshly built
        // shared libraries (release binaries use $ORIGIN only).
        module.addRPath(native_lib.getEmittedBinDirectory());
        module.addRPath(ui_lib.getEmittedBinDirectory());
        const run = b.addRunArtifact(b.addTest(.{ .root_module = module }));
        b.step(name, description).dependOn(&run.step);
        test_step.dependOn(&run.step);
    }
}

fn cFlags(ctx: Ctx) []const []const u8 {
    return if (ctx.has_x11)
        &.{ "-std=c11", "-D_GNU_SOURCE", "-DTALKIES_HAVE_X11" }
    else
        &.{ "-std=c11", "-D_GNU_SOURCE" };
}

/// S1-mini cleanup runtime on top of llama.cpp. Rarely changes.
fn addNativeLib(ctx: Ctx) *std.Build.Step.Compile {
    const b = ctx.b;
    const module = b.createModule(.{ .target = ctx.target, .optimize = ctx.optimize, .link_libc = true });
    module.addCSourceFile(.{ .file = b.path("src/native/s1_runtime.c"), .flags = cFlags(ctx) });
    // CrispASR is dlmopen'ed at run time, never linked: only its pinned header is needed here.
    module.addCSourceFile(.{ .file = b.path("src/native/crispasr_runtime.c"), .flags = cFlags(ctx) });
    module.addIncludePath(b.path("src/native"));
    module.addSystemIncludePath(b.path("vendor/crispasr/include"));
    addNativePrefix(ctx, module);
    module.linkSystemLibrary("llama", .{});
    // Resolve the bundled libllama next to this library.
    module.addRPathSpecial("$ORIGIN");
    return b.addLibrary(.{
        .name = "talkies-native",
        .linkage = .dynamic,
        .root_module = module,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });
}

/// Install the pinned CrispASR release (build.zig.zon) into lib/crispasr/,
/// with its MIT license and third-party notices. Talkies loads it into a
/// private namespace (src/native/crispasr_runtime.c); a missing runtime only
/// means Phonon-2 is unavailable and Whisper is used.
fn installCrispAsr(ctx: Ctx) void {
    const b = ctx.b;
    const target = ctx.target.result;
    if (target.os.tag != .linux or target.abi.isMusl()) return;
    const dep_name = switch (target.cpu.arch) {
        .x86_64 => "crispasr_linux_x86_64",
        .aarch64 => "crispasr_linux_arm64",
        else => return,
    };
    const dep = b.lazyDependency(dep_name, .{}) orelse return;
    for (crispasr_libraries) |lib| {
        if (lib.optional and target.cpu.arch != .x86_64) continue;
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(dep.path(b.fmt("lib/{s}", .{lib.file})), .lib, b.fmt("crispasr/{s}", .{lib.soname})).step);
    }
    for ([_][]const u8{ "LICENSE", "THIRD_PARTY_NOTICES.txt" }) |name| {
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(dep.path(name), .lib, b.fmt("crispasr/{s}", .{name})).step);
    }
}

/// GTK4 windows (HUD, settings, status monitor, YAP) and the D-Bus tray.
/// The fastest-moving C code; isolated so GTK stays off the app link line.
fn addUiLib(ctx: Ctx) *std.Build.Step.Compile {
    const b = ctx.b;
    const module = b.createModule(.{ .target = ctx.target, .optimize = ctx.optimize, .link_libc = true });
    const sources = [_][]const u8{
        "src/ui/hud_gtk.c",
        "src/ui/settings_gtk.c",
        "src/ui/tray_sni.c",
        "src/ui/daemon_status_gtk.c",
        "src/ui/yap_window_gtk.c",
        "src/ui/loop_glib.c",
    };
    for (sources) |source| module.addCSourceFile(.{ .file = b.path(source), .flags = cFlags(ctx) });
    module.addIncludePath(b.path("src/ui"));
    if (ctx.has_x11) module.linkSystemLibrary("X11", .{});
    for ([_][]const u8{ "gtk4", "glib-2.0", "gobject-2.0", "gio-2.0", "dbus-1" }) |lib| {
        module.linkSystemLibrary(lib, .{});
    }
    addSystemIncludes(ctx, module);
    return b.addLibrary(.{
        .name = "talkies-ui",
        .linkage = .dynamic,
        .root_module = module,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });
}

fn addCoreModule(ctx: Ctx) *std.Build.Module {
    return ctx.b.createModule(.{
        .root_source_file = ctx.b.path("src/core/core.zig"),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
    });
}

fn addEngineModule(ctx: Ctx, core: *std.Build.Module, native_lib: *std.Build.Step.Compile) *std.Build.Module {
    const b = ctx.b;
    const module = b.createModule(.{
        .root_source_file = b.path("src/engine/engine.zig"),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
    });
    module.addImport("core", core);

    addCImport(ctx, module, "c_audio", "audio.h");
    addCImport(ctx, module, "c_hotkey", "hotkey.h");
    addCImport(ctx, module, "c_input", "input.h");
    addCImport(ctx, module, "c_s1_runtime", "s1_runtime.h");
    addCImport(ctx, module, "c_crispasr_runtime", "crispasr_runtime.h");
    addCImport(ctx, module, "c_vad", "vad.h");
    addCImport(ctx, module, "c_whisper", "whisper.h");

    module.linkSystemLibrary("pulse-simple", .{});
    module.linkSystemLibrary("pulse", .{});
    addNativePrefix(ctx, module);
    module.linkSystemLibrary("whisper", .{});
    if (ctx.has_x11) module.linkSystemLibrary("X11", .{});
    // libfvad (WebRTC VAD) is vendored and tiny; it stays static.
    module.addObjectFile(b.path("vendor/libfvad/lib/libfvad.a"));
    module.addIncludePath(b.path("vendor/libfvad/include"));
    linkShared(module, native_lib);
    return module;
}

fn addAppModule(
    ctx: Ctx,
    core: *std.Build.Module,
    engine: *std.Build.Module,
    ui_lib: *std.Build.Step.Compile,
    build_options: *std.Build.Step.Options,
) *std.Build.Module {
    const b = ctx.b;
    const module = b.createModule(.{
        .root_source_file = b.path("src/app/main.zig"),
        .target = ctx.target,
        .optimize = ctx.optimize,
        .link_libc = true,
    });
    module.addImport("core", core);
    module.addImport("engine", engine);
    module.addImport("build_options", build_options.createModule());

    addCImport(ctx, module, "c_daemon_status", "daemon_status.h");
    addCImport(ctx, module, "c_hud", "hud.h");
    addCImport(ctx, module, "c_loop", "loop.h");
    addCImport(ctx, module, "c_settings", "settings.h");
    addCImport(ctx, module, "c_tray", "tray.h");
    addCImport(ctx, module, "c_yap_window", "yap_window.h");
    addCImport(ctx, module, "c_sqlite3", "sqlite3.h");

    module.addAnonymousImport("sound_start", .{ .root_source_file = b.path("assets/start-fast.wav") });
    module.addAnonymousImport("sound_stop", .{ .root_source_file = b.path("assets/stop.wav") });
    module.linkSystemLibrary("sqlite3", .{}); // YAP session history
    linkShared(module, ui_lib);
    // Installed layout: <app>/talkies + <app>/lib/*.so; zig-out: bin/ + lib/.
    module.addRPathSpecial("$ORIGIN/lib");
    module.addRPathSpecial("$ORIGIN/../lib");
    return module;
}

/// Link a shared library built here by path. `linkLibrary` would also add
/// its build-cache directory to RUNPATH: a cwd-relative path that would let
/// a planted .zig-cache/ directory inject libraries. RUNPATH stays $ORIGIN-only.
fn linkShared(module: *std.Build.Module, lib: *std.Build.Step.Compile) void {
    module.addObjectFile(lib.getEmittedBin());
}

fn addCImport(ctx: Ctx, module: *std.Build.Module, name: []const u8, header: []const u8) void {
    const b = ctx.b;
    const translation = b.addTranslateC(.{
        .root_source_file = b.path(b.fmt("src/c_headers/{s}", .{header})),
        .target = ctx.target,
        // Translate-C needs a concrete mode; null means the module default.
        .optimize = ctx.optimize orelse .debug,
    });
    translation.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
    translation.addSystemIncludePath(.{ .cwd_relative = "/usr/local/include" });
    if (ctx.native_prefix) |prefix| translation.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{prefix}) });
    for ([_][]const u8{ "src/ui", "src/native", "vendor/libfvad/include" }) |dir| {
        translation.addIncludePath(b.path(dir));
    }
    module.addImport(name, translation.createModule());
}

/// Search -Dnative-prefix before the system for whisper.cpp / llama.cpp.
fn addNativePrefix(ctx: Ctx, module: *std.Build.Module) void {
    const prefix = ctx.native_prefix orelse return;
    module.addIncludePath(.{ .cwd_relative = ctx.b.fmt("{s}/include", .{prefix}) });
    module.addLibraryPath(.{ .cwd_relative = ctx.b.fmt("{s}/lib", .{prefix}) });
}

/// Fallback include paths for distros whose pkg-config metadata is
/// incomplete (pkg-config is consulted first via linkSystemLibrary).
fn addSystemIncludes(ctx: Ctx, module: *std.Build.Module) void {
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
    const multiarch = ctx.b.fmt("/usr/lib/{s}-linux-gnu", .{@tagName(ctx.target.result.cpu.arch)});
    for ([_][]const u8{ "glib-2.0", "graphene-1.0", "dbus-1.0" }) |lib| {
        module.addIncludePath(.{ .cwd_relative = ctx.b.fmt("{s}/{s}/include", .{ multiarch, lib }) });
    }
}
