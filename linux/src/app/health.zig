//! System detection: a short, honest report of what Talkies needs and
//! whether it has it. Shown as a single "Ready" line when all is well, and
//! only the problems (each with one concrete fix) when not.

const std = @import("std");
const utils = @import("core").utils;
const config = @import("config.zig");

pub const Level = enum(u8) { ok = 0, warn = 1, fail = 2 };

pub const Id = enum { desktop, audio, microphone, hotkey, paste, clipboard, tray, recognizer, model };

pub const HotkeySource = enum { x11_grab, evdev, compositor_only };

pub const Check = struct {
    id: Id,
    level: Level,
    title: []const u8,
    detail: []const u8,
    /// Empty when level == .ok.
    fix: []const u8 = "",
};

/// What the caller already knows (the daemon has live answers; `doctor`
/// probes them itself).
pub const Probe = struct {
    hotkey: HotkeySource,
    tray_host: bool,
    model: ?[]const u8 = null,
    /// Size of the model download still needed; 0 when installed.
    model_missing_bytes: u64 = 0,
    speech: ?SpeechStatus = null,
};

/// Which recognizer dictation uses (Phonon-2 first, Whisper fallback).
pub const SpeechStatus = struct {
    /// Phonon-2 transcribes; Whisper is only the fallback.
    phonon_active: bool,
    /// Why Phonon-2 is not used, when it is not.
    reason: []const u8 = "",
    /// The user chose Phonon-2 explicitly, so running without it is a warning.
    phonon_selected: bool = false,
    /// Phonon-2 is not downloaded.
    phonon_missing: bool = false,
    /// Phonon-2 is installed but could not load or run.
    phonon_failed: bool = false,
};

pub const phonon_download_fix = "Download Phonon-2 (674 MB) in Settings > Transcription, or run: talkies models";

fn speechCheck(report: *Report, status: SpeechStatus, whisper_model: []const u8) Check {
    if (status.phonon_active) return .{
        .id = .recognizer,
        .level = .ok,
        .title = "Recognizer",
        .detail = report.fmt("Phonon-2 (Whisper {s} as fallback)", .{whisper_model}),
    };
    if (status.phonon_failed) return .{
        .id = .recognizer,
        .level = .warn,
        .title = "Recognizer",
        .detail = report.fmt("Using Whisper {s}; Phonon-2 could not load: {s}", .{ whisper_model, status.reason }),
        .fix = "Reinstall Talkies so its lib/crispasr runtime is present, or set speech_engine = \"whisper\".",
    };
    return .{
        .id = .recognizer,
        .level = if (status.phonon_missing and status.phonon_selected) .warn else .ok,
        .title = "Recognizer",
        .detail = report.fmt("Whisper {s} ({s})", .{ whisper_model, status.reason }),
        .fix = if (status.phonon_missing) phonon_download_fix else "",
    };
}

pub const Report = struct {
    arena: std.heap.ArenaAllocator,
    checks: std.ArrayList(Check) = .empty,

    pub fn deinit(self: *Report) void {
        self.arena.deinit();
    }

    pub fn worst(self: *const Report) Level {
        var level: Level = .ok;
        for (self.checks.items) |c| {
            if (@intFromEnum(c.level) > @intFromEnum(level)) level = c.level;
        }
        return level;
    }

    /// First failure, else first warning, else null.
    pub fn firstProblem(self: *const Report) ?Check {
        for ([_]Level{ .fail, .warn }) |wanted| {
            for (self.checks.items) |c| if (c.level == wanted) return c;
        }
        return null;
    }

    pub fn get(self: *const Report, id: Id) ?Check {
        for (self.checks.items) |c| if (c.id == id) return c;
        return null;
    }

    /// One line for the tray tooltip / status row.
    pub fn summary(self: *const Report, buf: []u8, hotkey_name: []const u8) []const u8 {
        if (self.firstProblem()) |p| return std.fmt.bufPrint(buf, "{s}: {s}", .{ p.title, p.detail }) catch p.title;
        return std.fmt.bufPrint(buf, "Ready - press {s} to dictate", .{hotkey_name}) catch "Ready";
    }

    fn add(self: *Report, check: Check) !void {
        try self.checks.append(self.arena.allocator(), check);
    }

    fn fmt(self: *Report, comptime f: []const u8, args: anytype) []const u8 {
        return std.fmt.allocPrint(self.arena.allocator(), f, args) catch "";
    }
};

pub fn run(allocator: std.mem.Allocator, cfg: *const config.Config, probe: Probe) !Report {
    var report: Report = .{ .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer report.deinit();

    const wayland = std.mem.eql(u8, cfg.getEffectivePlatform(), "wayland");
    const desktop = desktopName();
    try report.add(.{
        .id = .desktop,
        .level = .ok,
        .title = "Desktop",
        .detail = report.fmt("{s} ({s})", .{ desktop, if (wayland) "Wayland" else "X11" }),
    });

    // Audio server + microphone
    const pactl_info = utils.runCapture(allocator, &.{ "pactl", "info" }) catch null;
    defer if (pactl_info) |out| allocator.free(out);
    if (pactl_info) |info| {
        try report.add(.{ .id = .audio, .level = .ok, .title = "Audio", .detail = report.fmt("{s}", .{serverName(info)}) });
        try report.add(try microphoneCheck(&report, allocator, cfg));
    } else {
        try report.add(.{
            .id = .audio,
            .level = .fail,
            .title = "Audio",
            .detail = "No audio server is running",
            .fix = audioFix(desktop),
        });
    }

    // Hotkey
    try report.add(switch (probe.hotkey) {
        .x11_grab => .{ .id = .hotkey, .level = .ok, .title = "Hotkey", .detail = "Right Alt (X11)" },
        .evdev => .{ .id = .hotkey, .level = .ok, .title = "Hotkey", .detail = "Right Alt" },
        .compositor_only => .{
            .id = .hotkey,
            .level = .warn,
            .title = "Hotkey",
            .detail = "Right Alt needs keyboard access on Wayland",
            .fix = "Join the input group (usermod -aG input $USER, then log in again), or bind scripts/talkies-hotkey.sh in your compositor.",
        },
    });

    // Typing into apps
    if (!cfg.auto_paste) {
        try report.add(.{ .id = .paste, .level = .ok, .title = "Output", .detail = "Copy to clipboard only" });
    } else if (canWrite("/dev/uinput")) {
        try report.add(.{ .id = .paste, .level = .ok, .title = "Output", .detail = "Types into the focused app" });
    } else {
        try report.add(.{
            .id = .paste,
            .level = .fail,
            .title = "Output",
            .detail = "Can't type into apps (/dev/uinput not writable)",
            .fix = "Allow access to /dev/uinput (input group or a udev rule), or turn off \"Insert at cursor\" in Settings.",
        });
    }

    const clip_tool: []const u8 = if (wayland) "wl-copy" else "xclip";
    if (onPath(clip_tool)) {
        try report.add(.{ .id = .clipboard, .level = .ok, .title = "Clipboard", .detail = report.fmt("{s}", .{clip_tool}) });
    } else {
        try report.add(.{
            .id = .clipboard,
            .level = .fail,
            .title = "Clipboard",
            .detail = report.fmt("{s} is not installed", .{clip_tool}),
            .fix = installHint(&report, if (wayland) "wl-clipboard" else "xclip"),
        });
    }

    if (probe.tray_host) {
        try report.add(.{ .id = .tray, .level = .ok, .title = "Tray", .detail = "Shown in your panel" });
    } else {
        const gnome = std.mem.indexOf(u8, desktop, "GNOME") != null;
        try report.add(.{
            .id = .tray,
            .level = .warn,
            .title = "Tray",
            .detail = "Your panel has no system tray",
            .fix = if (gnome) "Install the \"AppIndicator and KStatusNotifierItem Support\" GNOME extension." else "Add a system tray widget to your panel; the hotkey works without it.",
        });
    }

    if (probe.speech) |status| try report.add(speechCheck(&report, status, probe.model orelse cfg.model));

    if (probe.model) |model| {
        if (probe.model_missing_bytes == 0) {
            try report.add(.{ .id = .model, .level = .ok, .title = "Speech model", .detail = report.fmt("Whisper {s}", .{model}) });
        } else {
            try report.add(.{
                .id = .model,
                .level = .warn,
                .title = "Speech model",
                .detail = report.fmt("Whisper {s} is not downloaded yet ({d} MB)", .{ model, probe.model_missing_bytes / 1_000_000 }),
                .fix = "It downloads automatically the first time Talkies starts (once, then works offline). To fetch it now: talkies models",
            });
        }
    }
    return report;
}

/// Concrete advice for starting audio, based on how this system boots.
fn audioFix(desktop: []const u8) []const u8 {
    const systemd = std.c.access("/run/systemd/system", std.c.F_OK) == 0;
    if (systemd) return "Run: systemctl --user enable --now pipewire pipewire-pulse wireplumber";
    if (onPath("gentoo-pipewire-launcher")) {
        if (std.mem.eql(u8, desktop, "Hyprland")) {
            return "Run gentoo-pipewire-launcher, and add `exec-once = gentoo-pipewire-launcher` to hyprland.conf.";
        }
        return "Run gentoo-pipewire-launcher, and add it to your session autostart.";
    }
    if (onPath("pipewire")) return "Start pipewire, pipewire-pulse and wireplumber from your session autostart.";
    return "Install and start PipeWire (with pipewire-pulse) or PulseAudio.";
}

/// "Install <pkg>: <command>" for the package manager this system uses.
fn installHint(report: *Report, package: []const u8) []const u8 {
    const managers = [_]struct { tool: []const u8, command: []const u8 }{
        .{ .tool = "apt-get", .command = "sudo apt install" },
        .{ .tool = "dnf", .command = "sudo dnf install" },
        .{ .tool = "zypper", .command = "sudo zypper install" },
        .{ .tool = "pacman", .command = "sudo pacman -S" },
        .{ .tool = "emerge", .command = "emerge --ask" },
        .{ .tool = "xbps-install", .command = "sudo xbps-install" },
        .{ .tool = "apk", .command = "sudo apk add" },
    };
    for (managers) |m| {
        if (onPath(m.tool)) {
            const name = if (std.mem.eql(u8, m.tool, "emerge")) gentooAtom(package) else package;
            return report.fmt("Install {s}: {s} {s}", .{ package, m.command, name });
        }
    }
    return report.fmt("Install {s} with your package manager.", .{package});
}

fn gentooAtom(package: []const u8) []const u8 {
    if (std.mem.eql(u8, package, "xclip")) return "x11-misc/xclip";
    if (std.mem.eql(u8, package, "wl-clipboard")) return "gui-apps/wl-clipboard";
    return package;
}

/// XDG_CURRENT_DESKTOP, with the Hyprland/Sway signatures as fallbacks.
pub fn desktopName() []const u8 {
    if (utils.getEnv("XDG_CURRENT_DESKTOP")) |name| {
        if (name.len > 0) return name;
    }
    if (utils.getEnv("HYPRLAND_INSTANCE_SIGNATURE") != null) return "Hyprland";
    if (utils.getEnv("SWAYSOCK") != null) return "sway";
    return "Unknown desktop";
}

fn serverName(info: []const u8) []const u8 {
    var lines = std.mem.splitScalar(u8, info, '\n');
    while (lines.next()) |line| {
        const key = "Server Name: ";
        if (std.mem.startsWith(u8, line, key)) {
            const name = line[key.len..];
            // "PulseAudio (on PipeWire 1.4.2)" -> report what actually runs.
            if (std.mem.indexOf(u8, name, "PipeWire")) |at| return std.mem.trimEnd(u8, name[at..], ")");
            return name;
        }
    }
    return "Running";
}

fn microphoneCheck(report: *Report, allocator: std.mem.Allocator, cfg: *const config.Config) !Check {
    if (cfg.audio_device.len == 0) {
        return .{ .id = .microphone, .level = .ok, .title = "Microphone", .detail = "System default" };
    }
    const sources = utils.runCapture(allocator, &.{ "pactl", "list", "sources", "short" }) catch
        return .{ .id = .microphone, .level = .ok, .title = "Microphone", .detail = "Selected device" };
    defer allocator.free(sources);
    if (std.mem.indexOf(u8, sources, cfg.audio_device) != null) {
        return .{ .id = .microphone, .level = .ok, .title = "Microphone", .detail = "Selected device connected" };
    }
    return .{
        .id = .microphone,
        .level = .fail,
        .title = "Microphone",
        .detail = report.fmt("Selected microphone is not connected", .{}),
        .fix = "Reconnect it, or choose another in Settings > Transcription.",
    };
}

fn canWrite(path: [:0]const u8) bool {
    return std.c.access(path.ptr, std.c.W_OK) == 0;
}

fn onPath(name: []const u8) bool {
    const path = utils.getEnv("PATH") orelse return false;
    var dirs = std.mem.splitScalar(u8, path, ':');
    var buf: [std.fs.max_path_bytes:0]u8 = undefined;
    while (dirs.next()) |dir| {
        if (dir.len == 0) continue;
        const full = std.fmt.bufPrintSentinel(&buf, "{s}/{s}", .{ dir, name }, 0) catch continue;
        if (std.c.access(full.ptr, std.c.X_OK) == 0) return true;
    }
    return false;
}

test "server name prefers the real backend" {
    try std.testing.expectEqualStrings("PipeWire 1.4.2", serverName("Server String: x\nServer Name: PulseAudio (on PipeWire 1.4.2)\n"));
    try std.testing.expectEqualStrings("pulseaudio", serverName("Server Name: pulseaudio\n"));
}

test "summary shows the worst problem first, else Ready" {
    var report: Report = .{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator) };
    defer report.deinit();
    var buf: [128]u8 = undefined;
    try report.add(.{ .id = .tray, .level = .warn, .title = "Tray", .detail = "none" });
    try report.add(.{ .id = .audio, .level = .fail, .title = "Audio", .detail = "No audio server is running" });
    try std.testing.expectEqualStrings("Audio: No audio server is running", report.summary(&buf, "Right Alt"));
    try std.testing.expectEqual(Level.fail, report.worst());

    var clean: Report = .{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator) };
    defer clean.deinit();
    try std.testing.expectEqualStrings("Ready - press Right Alt to dictate", clean.summary(&buf, "Right Alt"));
}

test "recognizer check names the active engine and offers the explicit download" {
    var report: Report = .{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator) };
    defer report.deinit();

    const active = speechCheck(&report, .{ .phonon_active = true }, "base");
    try std.testing.expectEqual(Level.ok, active.level);
    try std.testing.expectEqualStrings("Phonon-2 (Whisper base as fallback)", active.detail);

    const missing_auto = speechCheck(&report, .{ .phonon_active = false, .reason = "Phonon-2 is not downloaded", .phonon_missing = true }, "base");
    try std.testing.expectEqual(Level.ok, missing_auto.level);
    try std.testing.expectEqualStrings("Whisper base (Phonon-2 is not downloaded)", missing_auto.detail);
    try std.testing.expectEqualStrings(phonon_download_fix, missing_auto.fix);

    const missing_selected = speechCheck(&report, .{ .phonon_active = false, .reason = "Phonon-2 is not downloaded", .phonon_missing = true, .phonon_selected = true }, "small");
    try std.testing.expectEqual(Level.warn, missing_selected.level);

    const failed = speechCheck(&report, .{ .phonon_active = false, .reason = "libcrispasr.so.1 missing", .phonon_failed = true }, "base");
    try std.testing.expectEqual(Level.warn, failed.level);
    try std.testing.expect(std.mem.indexOf(u8, failed.detail, "libcrispasr.so.1 missing") != null);

    const whisper_only = speechCheck(&report, .{ .phonon_active = false, .reason = "Whisper is selected" }, "base");
    try std.testing.expectEqual(Level.ok, whisper_only.level);
    try std.testing.expectEqualStrings("", whisper_only.fix);
}

test "PATH lookup finds sh" {
    try std.testing.expect(onPath("sh"));
    try std.testing.expect(!onPath("definitely-not-a-real-binary-talkies"));
}
