//! Talkies daemon: one event loop for X11 and Wayland that mirrors the macOS
//! app flow.
//!
//!   hotkey (X11 grab | compositor binding over WebSocket | HUD | tray)
//!     -> Trigger (push-to-talk vs tap-to-toggle)
//!     -> record (live level -> HUD waveform)
//!     -> worker thread: VAD -> Whisper -> enhancer -> insert / speak
//!     -> HUD "Done!" -> auto-hide after 1.5s
//!
//! Threading: GTK, D-Bus, X11 and all UI state live on the main thread. The
//! worker only touches the services it owns while a job runs (Whisper, S1,
//! TextInserter) plus atomics; config changes are deferred until no job runs.

const std = @import("std");
const utils = @import("core").utils;
const config = @import("config.zig");
const audio = @import("engine").audio;
const whisper = @import("engine").whisper;
const cleanup = @import("engine").cleanup;
const enhance = @import("enhance.zig");
const input = @import("engine").input;
const clipboard = @import("engine").clipboard;
const hotkey = @import("engine").hotkey;
const websocket = @import("engine").websocket;
const daemon_ws = @import("daemon_ws.zig");
const daemon_status_window = @import("daemon_status_window.zig");
const audio_processing = @import("engine").audio_processing;
const vad = @import("engine").vad;
const yap_sandbox = @import("yap_sandbox.zig");
const yap_sessions = @import("yap_sessions.zig");
const yap_window = @import("yap_window.zig");
const trigger_mod = @import("trigger.zig");
const build_options = @import("build_options");

const c_hud = @import("c_hud");
const c_settings = @import("c_settings");
const c_tray = @import("c_tray");
const c_loop = @import("c_loop");
const evdev_hotkey = @import("engine").evdev_hotkey;
const sounds = @import("sounds.zig");
const app_state = @import("state.zig");
const Phase = app_state.Phase;
const health = @import("health.zig");
const c_gtk = @import("c_daemon_status");

const default_ws_port: u16 = 6789;

/// `TALKIES_WS_PORT` lets a development build run beside an installed daemon.
fn wsPort() u16 {
    const value = utils.getEnv("TALKIES_WS_PORT") orelse return default_ws_port;
    return std.fmt.parseInt(u16, value, 10) catch |err| {
        utils.logError("Ignoring invalid TALKIES_WS_PORT '{s}': {}", .{ value, err });
        return default_ws_port;
    };
}
/// Keep recording briefly after stop so trailing words aren't clipped.
const tail_ms: c_uint = 350;
/// macOS collapses the panel 2.5s after a successful insertion. Errors,
/// "no speech" and manual-paste results stay until the user dismisses them.
const collapse_after_complete_ms: c_uint = 2500;
/// Without a visible panel nothing can dismiss a result, so return to idle.
const idle_after_result_headless_ms: c_uint = 3000;
const level_broadcast_interval_ms: i64 = 50;
/// HUD waveform refresh while recording (~30 fps).
const level_interval_ms: c_uint = 33;

/// Mirrors TalkiesHudStage in hud_gtk.h and PipelineStage on macOS.
pub const Stage = enum(u8) {
    idle = 0,
    loading_model,
    recording,
    transcribing,
    cleaning,
    enhancing_ollama,
    enhancing_lm_studio,
    inserting,
    complete,
    @"error",
    no_speech,
    cleanup_fallback,
    clipboard_fallback,

    pub fn text(self: Stage) []const u8 {
        return switch (self) {
            .idle => "Ready",
            .loading_model => "Loading model...",
            .recording => "Recording...",
            .transcribing => "Transcribing...",
            .cleaning => "Cleaning up with S1-mini...",
            .enhancing_ollama => "Enhancing with Ollama...",
            .enhancing_lm_studio => "Enhancing with LM Studio...",
            .inserting => "Inserting text...",
            .complete => "Done!",
            .@"error" => "Error",
            .no_speech => "No speech detected",
            .cleanup_fallback => "Using the raw transcript",
            .clipboard_fallback => "Manual paste needed",
        };
    }
};

comptime {
    std.debug.assert(@intFromEnum(Stage.@"error") == c_hud.TALKIES_HUD_ERROR);
    std.debug.assert(@intFromEnum(Stage.enhancing_lm_studio) == c_hud.TALKIES_HUD_ENHANCING_LM_STUDIO);
    std.debug.assert(@intFromEnum(Stage.clipboard_fallback) == c_hud.TALKIES_HUD_CLIPBOARD_FALLBACK);
}

/// Map an RMS amplitude to the macOS meter scale: dB clamped to -60..0,
/// normalized to 0..1.
pub fn normalizeLevel(rms: f32) f32 {
    if (rms <= 0.000001) return 0;
    const db = 20.0 * std.math.log10(rms);
    return (std.math.clamp(db, -60.0, 0.0) + 60.0) / 60.0;
}

const Outcome = enum {
    delivered,
    no_voice,
    failed,
    yap,
    /// Typing into the app failed; the text was put on the clipboard instead.
    manual_paste,
};

/// One recording's trip through the pipeline on a worker thread.
const Job = struct {
    daemon: *Daemon,
    stage: std.atomic.Value(u8) = .init(@intFromEnum(Stage.transcribing)),
    done: std.atomic.Value(bool) = .init(false),
    outcome: Outcome = .failed,
    text: ?[]u8 = null,
    error_buf: [160]u8 = undefined,
    error_len: usize = 0,
    /// The enhancer failed or was unavailable, so the raw transcript was used.
    cleanup_failed: bool = false,
    /// Shown under the result (e.g. why manual paste is needed).
    notice_buf: [200]u8 = undefined,
    notice_len: usize = 0,
    duration_ms: i64 = 0,
    /// Snapshot of YAP routing at spawn time (main thread owns yap state).
    route_to_yap: bool = false,
    /// S1-mini weights present; otherwise cleanup is skipped, never fetched.
    s1_ready: bool = false,
    thread: std.Thread = undefined,

    fn setStage(self: *Job, stage: Stage) void {
        self.stage.store(@intFromEnum(stage), .release);
        self.daemon.wake();
    }

    fn fail(self: *Job, comptime fmt: []const u8, args: anytype) void {
        const msg = std.fmt.bufPrint(&self.error_buf, fmt, args) catch self.error_buf[0..];
        self.error_len = msg.len;
        self.outcome = .failed;
    }

    fn errorMessage(self: *const Job) []const u8 {
        return self.error_buf[0..self.error_len];
    }

    fn setNotice(self: *Job, comptime fmt: []const u8, args: anytype) void {
        const msg = std.fmt.bufPrint(&self.notice_buf, fmt, args) catch self.notice_buf[0..];
        self.notice_len = msg.len;
    }

    fn notice(self: *const Job) ?[]const u8 {
        return if (self.notice_len == 0) null else self.notice_buf[0..self.notice_len];
    }

    fn run(self: *Job) void {
        const started = utils.monotonicMilliseconds();
        self.process();
        self.duration_ms = utils.monotonicMilliseconds() - started;
        self.done.store(true, .release);
        self.daemon.wake();
    }

    fn process(self: *Job) void {
        const d = self.daemon;
        const cfg = &d.cfg;
        const allocator = d.allocator;

        self.setStage(.transcribing);
        const recording_path = d.recording_path;
        const vad_trimmed_path = d.vad_path;
        var audio_path: []const u8 = recording_path;
        if (cfg.vad_enabled) {
            const mode: vad.VadMode = switch (cfg.vad_mode) {
                0 => .quality,
                1 => .low_bitrate,
                3 => .very_aggressive,
                else => .aggressive,
            };
            const has_voice = audio_processing.trimSilenceFromWav(allocator, recording_path, vad_trimmed_path, mode) catch |err| blk: {
                utils.log("VAD failed ({}), transcribing untrimmed audio", .{err});
                break :blk true;
            };
            if (!has_voice) {
                self.outcome = .no_voice;
                return;
            }
            // trimSilenceFromWav only writes the trimmed file on success.
            if (std.Io.Dir.cwd().access(utils.io(), vad_trimmed_path, .{})) |_| {
                audio_path = vad_trimmed_path;
            } else |_| {}
        }

        const raw = d.whisper_service.transcribe(audio_path, cfg.vocabulary_prompt) catch |err| {
            self.fail("Transcription failed: {s}", .{@errorName(err)});
            return;
        };
        defer allocator.free(raw);
        const trimmed = std.mem.trim(u8, raw, &std.ascii.whitespace);
        if (trimmed.len == 0) {
            self.outcome = .no_voice;
            return;
        }

        const text = self.enhanceText(trimmed) catch |err| {
            self.fail("Out of memory: {s}", .{@errorName(err)});
            return;
        };
        self.text = text;

        if (self.route_to_yap) {
            self.outcome = .yap;
            return;
        }

        self.deliver(text);
    }

    /// Run the configured enhancer, falling back to the raw transcript on
    /// failure exactly like macOS does.
    fn enhanceText(self: *Job, raw: []const u8) ![]u8 {
        const d = self.daemon;
        const cfg = &d.cfg;
        switch (cfg.enhancer) {
            .none => return d.allocator.dupe(u8, raw),
            .s1_mini => {
                if (!self.s1_ready) {
                    utils.log("S1-mini not installed (Settings > Enhancement); inserting raw transcript", .{});
                    self.cleanup_failed = true;
                    return d.allocator.dupe(u8, raw);
                }
                self.setStage(.cleaning);
                return d.cleanup_service.clean(raw, cleanupOptions(cfg)) catch |err| {
                    utils.logError("S1-mini cleanup failed; keeping raw transcript: {}", .{err});
                    self.cleanup_failed = true;
                    return d.allocator.dupe(u8, raw);
                };
            },
            .ollama, .lm_studio => {
                self.setStage(if (cfg.enhancer == .ollama) .enhancing_ollama else .enhancing_lm_studio);
                return enhance.enhance(d.allocator, cfg, raw) catch |err| {
                    utils.logError("{s} enhancement failed; keeping raw transcript: {}", .{ cfg.enhancer.displayName(), err });
                    self.cleanup_failed = true;
                    return d.allocator.dupe(u8, raw);
                };
            },
        }
    }

    fn deliver(self: *Job, text: []const u8) void {
        const d = self.daemon;
        const cfg = &d.cfg;

        if (cfg.voice_assistant_mode) {
            speak(text);
            if (!cfg.insert_text_in_assistant_mode) {
                self.outcome = .delivered;
                return;
            }
        }

        if (cfg.auto_paste) {
            self.setStage(.inserting);
            d.inserter.insertTextAtCursor(text, cfg.paste_keybind, cfg.restore_clipboard) catch |err| {
                // Like macOS's manual-paste fallback: keep the words on the
                // clipboard so nothing is lost.
                utils.logError("Could not type into the focused app: {}", .{err});
                var clip = clipboard.Clipboard.init(d.allocator);
                defer clip.deinit();
                clip.copy(text) catch |copy_err| {
                    self.fail("Could not insert or copy text: {s}", .{@errorName(copy_err)});
                    return;
                };
                self.setNotice("Couldn't type into the app ({s}). The transcript is on the clipboard: press Ctrl+V.", .{@errorName(err)});
                self.outcome = .manual_paste;
                return;
            };
        } else {
            var clip = clipboard.Clipboard.init(d.allocator);
            defer clip.deinit();
            clip.copy(text) catch |err| {
                self.fail("Could not copy text: {s}", .{@errorName(err)});
                return;
            };
            self.setNotice("Copied to the clipboard. Press Ctrl+V in the target field.", .{});
        }
        self.outcome = .delivered;
    }
};

fn cleanupOptions(cfg: *const config.Config) cleanup.Options {
    return .{
        .style = switch (cfg.cleanup_style) {
            .casual => .casual,
            .semi_casual => .semi_casual,
            .semi_formal => .semi_formal,
        },
        .structure = switch (cfg.cleanup_structure) {
            .prose => .prose,
            .lists => .lists,
        },
        .context = switch (cfg.cleanup_context) {
            .general => .general,
            .email => .email,
        },
    };
}

/// Speak text with speech-dispatcher, falling back to espeak-ng
/// (the Linux stand-in for NSSpeechSynthesizer).
fn speak(text: []const u8) void {
    utils.runQuiet(&.{ "spd-say", "--wait", "--", text }) catch {
        utils.runQuiet(&.{ "espeak-ng", "--", text }) catch |err| {
            utils.logError("Voice assistant: no TTS available (install speech-dispatcher or espeak-ng): {}", .{err});
        };
    };
}

/// Audio capture on its own thread so blocking PulseAudio reads never stall
/// the UI. The main thread only reads `level` and the completion flags.
const Capture = struct {
    daemon: *Daemon,
    thread: std.Thread = undefined,
    stop_requested: std.atomic.Value(bool) = .init(false),
    finished: std.atomic.Value(bool) = .init(false),
    failed: std.atomic.Value(bool) = .init(false),
    /// Latest peak RMS as f32 bits.
    level_bits: std.atomic.Value(u32) = .init(0),

    fn level(self: *const Capture) f32 {
        return @bitCast(self.level_bits.load(.monotonic));
    }

    fn run(self: *Capture) void {
        defer {
            self.finished.store(true, .release);
            self.daemon.wake();
        }
        const d = self.daemon;
        const device: ?[]const u8 = if (d.cfg.audio_device.len > 0) d.cfg.audio_device else null;
        d.recorder.startRecording(d.recording_path, device) catch |err| {
            utils.logError("Could not start recording: {}", .{err});
            self.failed.store(true, .release);
            return;
        };
        var peak: f32 = 0;
        var chunks: usize = 0;
        while (!self.stop_requested.load(.acquire)) {
            _ = d.recorder.recordChunk() catch |err| {
                utils.logError("Recording failed: {}", .{err});
                self.failed.store(true, .release);
                break;
            };
            peak = @max(peak, d.recorder.getAudioLevel());
            chunks += 1;
            if (chunks % 5 == 0) { // ~20ms windows
                self.level_bits.store(@bitCast(peak), .monotonic);
                peak = 0;
            }
        }
        d.recorder.stopRecording() catch |err| {
            utils.logError("Could not finalize recording: {}", .{err});
            self.failed.store(true, .release);
        };
    }
};

const S1State = enum(u8) { missing, downloading, ready, failed };

pub const Daemon = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    pending_cfg: ?config.Config = null,

    /// Recordings live in a private 0700 runtime directory, never /tmp.
    recording_path: []u8,
    vad_path: []u8,

    whisper_service: whisper.WhisperService,
    cleanup_service: cleanup.Cleaner,
    inserter: input.TextInserter,
    recorder: audio.AudioRecorder,

    ws_server: *websocket.Server,
    state: *daemon_ws.DaemonState,
    /// eventfd that worker/capture/WebSocket threads write to wake the loop.
    wake_fd: std.posix.fd_t,
    hotkey_listener: ?hotkey.HotkeyListener = null,
    evdev: evdev_hotkey.Listener = .{},
    hotkey_name: [:0]const u8,

    hud: ?*c_hud.TalkiesHud = null,
    status_win: ?*daemon_status_window.DaemonStatusWindow = null,
    settings_win: ?*c_settings.TalkiesSettingsWindow = null,
    tray: ?*c_tray.TalkiesTray = null,

    trigger: trigger_mod.Trigger,
    /// Single source of truth for what the daemon is doing (see state.zig).
    phase: Phase = .starting,
    capture: ?*Capture = null,
    record_start_ms: i64 = 0,
    last_level_broadcast_ms: i64 = 0,
    level_timer: c_uint = 0,
    stop_timer: c_uint = 0,
    hide_timer: c_uint = 0,

    job: ?*Job = null,
    shown_stage: Stage = .idle,
    /// Latest system check; drives the tray tooltip and Settings status.
    health_report: ?health.Report = null,
    last_transcript: ?[:0]u8 = null,

    s1_state: std.atomic.Value(u8) = .init(@intFromEnum(S1State.missing)),
    s1_thread: ?std.Thread = null,
    s1_timer: c_uint = 0,

    // UI requests raised from GTK / D-Bus callbacks, handled in tick().
    request_toggle: bool = false,
    request_toggle_hud: bool = false,
    request_expand_hud: bool = false,
    request_dismiss: bool = false,
    /// Stage and detail shown when entering .complete / .failed.
    result_stage: Stage = .complete,
    result_detail_buf: [256]u8 = undefined,
    result_detail_len: usize = 0,
    request_settings: bool = false,
    quit: bool = false,

    // YAP interactive refinement (opt-in, Linux-only)
    yap_win: ?*yap_window.YapWindow = null,
    yap_sb: ?*yap_sandbox.Sandbox = null,
    yap_session_manager: ?*yap_sessions.SessionManager = null,
    yap_session_id: ?i64 = null,

    // -----------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------

    fn deinit(self: *Daemon) void {
        if (self.capture) |cap| {
            cap.stop_requested.store(true, .release);
            cap.thread.join();
            self.allocator.destroy(cap);
        }
        if (self.job) |job| {
            job.thread.join();
            self.freeJob(job);
        }
        if (self.s1_thread) |t| t.join();
        self.endYapSession();
        if (self.tray) |t| c_tray.talkies_tray_destroy(t);
        if (self.settings_win) |w| c_settings.talkies_settings_window_destroy(w);
        if (self.hud) |h| c_hud.talkies_hud_destroy(h);
        if (self.status_win) |w| w.destroy();
        if (self.hotkey_listener) |*l| l.deinit();
        self.evdev.deinit();
        if (self.last_transcript) |t| self.allocator.free(t);
        if (self.health_report) |*r| r.deinit();
        if (self.pending_cfg) |*p| p.deinit();
        self.recorder.deinit();
        self.inserter.deinit();
        self.cleanup_service.deinit();
        self.whisper_service.deinit();
        self.cfg.deinit();
        self.allocator.free(self.recording_path);
        self.allocator.free(self.vad_path);
        _ = std.os.linux.close(self.wake_fd);
    }

    fn wakeOpaque(ctx: *anyopaque) void {
        const self: *Daemon = @ptrCast(@alignCast(ctx));
        self.wake();
    }

    /// Wake the main loop from any thread.
    pub fn wake(self: *Daemon) void {
        const one: u64 = 1;
        const rc = std.os.linux.write(self.wake_fd, std.mem.asBytes(&one).ptr, @sizeOf(u64));
        // EAGAIN means the counter is already non-zero: the loop will wake.
        if (std.os.linux.errno(rc) != .SUCCESS and std.os.linux.errno(rc) != .AGAIN) {
            utils.logError("wake failed: {}", .{std.os.linux.errno(rc)});
        }
    }

    fn log(self: *Daemon, level: daemon_status_window.LogLevel, comptime fmt: []const u8, args: anytype) void {
        utils.log(fmt, args);
        if (self.status_win) |win| {
            var buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, fmt, args) catch return;
            win.addLog(level, msg);
        }
    }

    fn setStage(self: *Daemon, stage: Stage, detail: ?[]const u8) void {
        self.shown_stage = stage;
        var detail_buf: [256]u8 = undefined;
        const detail_z: ?[*:0]const u8 = if (detail) |dtl|
            (bufPrintZ(&detail_buf, "{s}", .{dtl}) catch @as([:0]const u8, "")).ptr
        else
            null;
        if (self.hud) |hud| c_hud.talkies_hud_set_stage(hud, @intFromEnum(stage), detail_z);
        if (self.status_win) |win| {
            win.setState(@tagName(stage));
            win.setActivity(stage.text());
        }
        if (self.tray) |t| {
            c_tray.talkies_tray_set_recording(t, @intFromBool(stage == .recording));
            var tip_buf: [256]u8 = undefined;
            var summary_buf: [256]u8 = undefined;
            const text = if (detail) |dtl| dtl else if (stage == .idle) self.idleSummary(&summary_buf) else stage.text();
            const tip = bufPrintZ(&tip_buf, "{s}", .{text}) catch @as([:0]const u8, "Talkies");
            c_tray.talkies_tray_set_status_text(t, tip.ptr);
        }
        self.broadcastStage(stage);
    }

    fn idleSummary(self: *Daemon, buf: []u8) []const u8 {
        const report = if (self.health_report) |*r| r else return "Ready";
        return report.summary(buf, self.hotkey_name);
    }

    /// Re-detect the system (cheap: a couple of pactl calls) and publish it.
    fn refreshHealth(self: *Daemon) void {
        const probe: health.Probe = .{
            .hotkey = if (self.hotkey_listener != null) .x11_grab else if (self.evdev.count > 0) .evdev else .compositor_only,
            .tray_host = self.tray != null and c_tray.talkies_tray_host_available() != 0,
            .model = self.cfg.model,
        };
        const report = health.run(self.allocator, &self.cfg, probe) catch |err| {
            utils.logError("System check failed: {}", .{err});
            return;
        };
        if (self.health_report) |*old| old.deinit();
        self.health_report = report;
        self.pushHealth();
        self.pushAttention();
        if (self.phase == .idle) self.setStage(.idle, null); // refresh tooltip
    }

    /// A failing check (no audio server, no way to type) replaces "Ready to
    /// dictate" in the panel, like macOS's "Microphone access needed".
    fn pushAttention(self: *Daemon) void {
        const hud = self.hud orelse return;
        const report = if (self.health_report) |*r| r else return;
        for (report.checks.items) |check| {
            if (check.level != .fail) continue;
            var status_buf: [200]u8 = undefined;
            var hint_buf: [300]u8 = undefined;
            const status = bufPrintZ(&status_buf, "{s}", .{check.detail}) catch @as([:0]const u8, "Setup needed");
            const hint = bufPrintZ(&hint_buf, "{s}", .{if (check.fix.len > 0) check.fix else "Open Settings for details."}) catch @as([:0]const u8, "");
            c_hud.talkies_hud_set_attention(hud, status.ptr, hint.ptr);
            return;
        }
        c_hud.talkies_hud_set_attention(hud, null, null);
    }

    fn pushHealth(self: *Daemon) void {
        const win = self.settings_win orelse return;
        const report = if (self.health_report) |*r| r else return;
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const items = a.alloc(c_settings.TalkiesHealthItem, report.checks.items.len) catch return;
        for (report.checks.items, items) |check, *item| {
            item.* = .{
                .level = @intFromEnum(check.level),
                .title = (utils.dupeZ(a, check.title) catch return).ptr,
                .detail = (utils.dupeZ(a, check.detail) catch return).ptr,
                .fix = (utils.dupeZ(a, check.fix) catch return).ptr,
            };
        }
        c_settings.talkies_settings_window_set_health(win, items.ptr, @intCast(items.len));
    }

    /// Name the actual cause when the microphone could not be opened.
    fn captureFailureMessage(self: *Daemon) []const u8 {
        self.refreshHealth();
        const report = if (self.health_report) |*r| r else return "Microphone unavailable";
        for ([_]health.Id{ .audio, .microphone }) |id| {
            if (report.get(id)) |check| {
                if (check.level == .fail) return check.detail;
            }
        }
        return "Microphone unavailable";
    }

    fn broadcastStage(self: *Daemon, stage: Stage) void {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{{\"type\":\"pipeline_stage\",\"data\":{{\"stage\":\"{s}\"}}}}", .{@tagName(stage)}) catch return;
        self.ws_server.broadcast(msg) catch |err| utils.logError("broadcast stage: {}", .{err});
    }

    fn setWsState(self: *Daemon, state: daemon_ws.State) void {
        self.state.setState(state) catch |err| utils.logError("broadcast state: {}", .{err});
    }

    /// The only way to change phase. Every surface (window, tray, WebSocket,
    /// status monitor) is updated here so they can never disagree.
    fn enter(self: *Daemon, next: Phase, detail: ?[]const u8) void {
        if (!app_state.allowed(self.phase, next)) {
            utils.logError("Ignoring invalid transition {s} -> {s}", .{ @tagName(self.phase), @tagName(next) });
            return;
        }
        self.phase = next;
        switch (next) {
            .starting => self.setStage(.loading_model, null),
            .idle => {
                self.collapseHud();
                self.setStage(.idle, null);
            },
            .recording => {
                self.expandHud();
                self.setStage(.recording, null);
            },
            .stopping => {}, // still shows Recording while the tail is captured
            .processing => self.setStage(.transcribing, null),
            .yap => {
                self.collapseHud();
                self.setStage(.idle, null);
            },
            .complete => {
                // .complete or .cleanup_fallback; both put themselves away.
                const stage = self.takeResultStage(.complete);
                self.setStage(stage, detail orelse self.resultDetail());
                self.scheduleCollapse(collapse_after_complete_ms);
            },
            .failed => {
                // .error, .no_speech or .clipboard_fallback: these stay open
                // until the user dismisses the panel (as on macOS).
                const stage = self.takeResultStage(.@"error");
                self.expandHud();
                self.setStage(stage, detail orelse self.resultDetail());
                if (!self.hudVisible()) self.scheduleCollapse(idle_after_result_headless_ms);
            },
        }
        // publicState() is the one mapping to the WebSocket contract.
        self.setWsState(std.meta.stringToEnum(daemon_ws.State, next.publicState()).?);
    }

    /// Finish a dictation: `stage` picks the result view, `detail` the line
    /// under it. Successful results auto-collapse; the others wait.
    fn enterResult(self: *Daemon, stage: Stage, detail: ?[]const u8) void {
        self.result_stage = stage;
        const n = if (detail) |dtl| @min(dtl.len, self.result_detail_buf.len) else 0;
        if (detail) |dtl| @memcpy(self.result_detail_buf[0..n], dtl[0..n]);
        self.result_detail_len = n;
        const phase: Phase = switch (stage) {
            .complete, .cleanup_fallback => .complete,
            else => .failed,
        };
        self.enter(phase, null);
    }

    fn takeResultStage(self: *Daemon, default: Stage) Stage {
        const stage = self.result_stage;
        self.result_stage = default;
        return switch (stage) {
            .complete, .cleanup_fallback, .@"error", .no_speech, .clipboard_fallback => stage,
            else => default,
        };
    }

    fn resultDetail(self: *Daemon) ?[]const u8 {
        const n = self.result_detail_len;
        self.result_detail_len = 0;
        return if (n == 0) null else self.result_detail_buf[0..n];
    }

    fn hudVisible(self: *Daemon) bool {
        const hud = self.hud orelse return false;
        return self.cfg.show_hud and c_hud.talkies_hud_is_visible(hud) != 0;
    }

    /// Show the panel opened up (recording, results, model loading).
    fn expandHud(self: *Daemon) void {
        self.cancelHide();
        const hud = self.hud orelse return;
        if (!self.cfg.show_hud) return;
        c_hud.talkies_hud_show(hud);
        c_hud.talkies_hud_set_expanded(hud, 1);
    }

    /// Rest as the waveform pill at the top of the screen (macOS idle state).
    fn collapseHud(self: *Daemon) void {
        self.cancelHide();
        const hud = self.hud orelse return;
        if (!self.cfg.show_hud) {
            c_hud.talkies_hud_hide(hud);
            return;
        }
        c_hud.talkies_hud_set_expanded(hud, 0);
        c_hud.talkies_hud_show(hud);
    }

    fn hideHud(self: *Daemon) void {
        self.cancelHide();
        if (self.hud) |hud| c_hud.talkies_hud_hide(hud);
    }

    fn cancelHide(self: *Daemon) void {
        c_loop.talkies_loop_remove(self.hide_timer);
        self.hide_timer = 0;
    }

    /// Collapse the panel and return to idle after `ms`, unless something
    /// new starts first.
    fn scheduleCollapse(self: *Daemon, ms: c_uint) void {
        self.cancelHide();
        self.hide_timer = c_loop.talkies_loop_timeout(ms, onHideTimer, self);
    }

    fn onHideTimer(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        self.hide_timer = 0;
        if (self.phase == .complete or self.phase == .failed) self.enter(.idle, null);
        return 0;
    }

    fn showError(self: *Daemon, message: []const u8) void {
        self.enterResult(.@"error", message);
    }

    // -----------------------------------------------------------------
    // Recording
    // -----------------------------------------------------------------

    fn applyAction(self: *Daemon, action: trigger_mod.Action) void {
        switch (action) {
            .none => {},
            .start => self.startRecording(),
            .stop => self.requestStop(),
        }
    }

    /// True while audio is being captured and no stop is pending.
    fn isRecording(self: *const Daemon) bool {
        return self.phase == .recording;
    }

    fn startRecording(self: *Daemon) void {
        if (!self.phase.canStartRecording() or self.capture != null or self.job != null) {
            self.log(.warn, "Busy ({s}); ignoring start", .{@tagName(self.phase)});
            return;
        }
        const cap = self.allocator.create(Capture) catch {
            self.showError("Out of memory");
            return;
        };
        cap.* = .{ .daemon = self };
        cap.thread = std.Thread.spawn(.{}, Capture.run, .{cap}) catch |err| {
            self.allocator.destroy(cap);
            self.log(.err, "Could not start capture thread: {}", .{err});
            self.showError("Could not start recording");
            return;
        };
        self.capture = cap;
        self.record_start_ms = utils.monotonicMilliseconds();
        // UI responds immediately; PulseAudio opens on the capture thread.
        self.enter(.recording, null);
        self.level_timer = c_loop.talkies_loop_timeout(level_interval_ms, onLevelTimer, self);
        if (self.cfg.sounds) sounds.play(.start);
    }

    fn requestStop(self: *Daemon) void {
        if (self.phase != .recording) return;
        self.enter(.stopping, null);
        // Keep recording briefly so trailing words aren't clipped.
        self.stop_timer = c_loop.talkies_loop_timeout(tail_ms, onStopTimer, self);
    }

    fn onStopTimer(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        self.stop_timer = 0;
        if (self.capture) |cap| cap.stop_requested.store(true, .release);
        return 0;
    }

    fn onLevelTimer(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        const cap = self.capture orelse {
            self.level_timer = 0;
            return 0;
        };
        const level = normalizeLevel(cap.level());
        const now = utils.monotonicMilliseconds();
        if (self.hud) |hud| {
            c_hud.talkies_hud_set_level(hud, level);
            c_hud.talkies_hud_set_elapsed(hud, @as(f64, @floatFromInt(now - self.record_start_ms)) / 1000.0);
        }
        if (now - self.last_level_broadcast_ms >= level_broadcast_interval_ms) {
            self.last_level_broadcast_ms = now;
            self.state.broadcastAudioLevel(level) catch |err| utils.logError("broadcast level: {}", .{err});
        }
        return 1;
    }

    /// Capture thread ended (stop requested or device failure).
    fn collectCapture(self: *Daemon) void {
        const cap = self.capture orelse return;
        if (!cap.finished.load(.acquire)) return;
        cap.thread.join();
        const failed = cap.failed.load(.acquire);
        self.allocator.destroy(cap);
        self.capture = null;
        c_loop.talkies_loop_remove(self.level_timer);
        c_loop.talkies_loop_remove(self.stop_timer);
        self.level_timer = 0;
        self.stop_timer = 0;

        if (failed) {
            self.state.broadcastError("Recording failed", "RECORDING_ERROR") catch |err| utils.logError("broadcast: {}", .{err});
            self.showError(self.captureFailureMessage());
            return;
        }
        if (self.cfg.sounds) sounds.play(.stop);
        self.enter(.processing, null);
        self.spawnJob() catch |err| {
            self.log(.err, "Could not start processing: {}", .{err});
            self.showError("Could not start processing");
        };
    }

    fn spawnJob(self: *Daemon) !void {
        const job = try self.allocator.create(Job);
        errdefer self.allocator.destroy(job);
        job.* = .{
            .daemon = self,
            .route_to_yap = self.yap_win != null or self.cfg.yap_mode_enabled,
            .s1_ready = self.s1Ready(),
        };
        job.thread = try std.Thread.spawn(.{}, Job.run, .{job});
        self.job = job;
    }

    fn freeJob(self: *Daemon, job: *Job) void {
        if (job.text) |t| self.allocator.free(t);
        self.allocator.destroy(job);
    }

    fn pollJob(self: *Daemon) !void {
        const job = self.job orelse return;
        if (!job.done.load(.acquire)) {
            const stage: Stage = @enumFromInt(job.stage.load(.acquire));
            if (stage != self.shown_stage) self.setStage(stage, null);
            return;
        }
        job.thread.join();
        self.job = null;
        defer self.freeJob(job);

        std.Io.Dir.deleteFileAbsolute(utils.io(), self.recording_path) catch |err| utils.logDebug("cleanup recording: {}", .{err});
        std.Io.Dir.deleteFileAbsolute(utils.io(), self.vad_path) catch |err| utils.logDebug("cleanup vad: {}", .{err});

        switch (job.outcome) {
            .delivered => {
                const text = job.text orelse "";
                self.rememberTranscript(text);
                self.state.broadcastTranscription(text, job.duration_ms) catch |err| utils.logError("broadcast: {}", .{err});
                self.log(.info, "Delivered {d} chars in {d}ms", .{ text.len, job.duration_ms });
                if (self.status_win) |win| win.setLastTranscription(text);
                if (job.cleanup_failed) {
                    self.enterResult(.cleanup_fallback, null);
                } else {
                    self.enterResult(.complete, job.notice());
                }
            },
            .manual_paste => {
                const text = job.text orelse "";
                self.rememberTranscript(text);
                self.state.broadcastTranscription(text, job.duration_ms) catch |err| utils.logError("broadcast: {}", .{err});
                self.log(.warn, "Manual paste needed: {s}", .{job.notice() orelse ""});
                self.enterResult(.clipboard_fallback, job.notice());
            },
            .no_voice => {
                self.log(.warn, "No speech detected", .{});
                if (self.yap_win != null) self.enter(.yap, null) else self.enterResult(.no_speech, null);
            },
            .failed => {
                self.log(.err, "{s}", .{job.errorMessage()});
                self.state.broadcastError(job.errorMessage(), "PIPELINE_ERROR") catch |err| utils.logError("broadcast: {}", .{err});
                self.showError(job.errorMessage());
            },
            .yap => {
                const text = job.text orelse "";
                self.rememberTranscript(text);
                self.state.broadcastTranscription(text, job.duration_ms) catch |err| utils.logError("broadcast: {}", .{err});
                try self.handleYapTranscript(text);
            },
        }
        try self.applyPendingConfig();
    }

    fn rememberTranscript(self: *Daemon, text: []const u8) void {
        const copy = utils.dupeZ(self.allocator, text) catch return;
        if (self.last_transcript) |old| self.allocator.free(old);
        self.last_transcript = copy;
        if (self.hud) |hud| {
            c_hud.talkies_hud_set_transcript(hud, copy.ptr);
            c_hud.talkies_hud_add_history(hud, copy.ptr);
        }
    }

    // -----------------------------------------------------------------
    // Input sources (each fires from the event loop; no polling)
    // -----------------------------------------------------------------

    fn handleKey(self: *Daemon, pressed: bool) void {
        const now = utils.monotonicMilliseconds();
        self.applyAction(if (pressed)
            self.trigger.press(now, self.isRecording())
        else
            self.trigger.release(now, self.isRecording()));
    }

    fn onX11Readable(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        const listener = if (self.hotkey_listener) |*l| l else return 0;
        while (listener.hasPendingEvents()) {
            const event = (listener.poll() catch |err| {
                utils.logError("X11 hotkey: {}", .{err});
                return 1;
            }) orelse continue;
            self.handleKey(event == .press);
        }
        return 1;
    }

    fn onEvdevReadable(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        for (self.evdev.devices()) |fd| {
            if (evdev_hotkey.Listener.read(fd)) |event| self.handleKey(event == .press);
        }
        return 1;
    }

    fn onWake(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        var counter: u64 = 0;
        _ = std.os.linux.read(self.wake_fd, std.mem.asBytes(&counter).ptr, @sizeOf(u64));
        return 1; // tick() runs after every loop iteration
    }

    fn onTrayReadable(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        if (self.tray) |t| c_tray.talkies_tray_process(t);
        return 1;
    }

    fn pollCommands(self: *Daemon) void {
        while (self.state.popRecordCommand()) |command| {
            const now = utils.monotonicMilliseconds();
            const recording = self.isRecording();
            self.applyAction(switch (command) {
                .start => if (recording) .none else self.trigger.toggle(false),
                .stop => if (recording) self.trigger.toggle(true) else .none,
                .toggle => self.trigger.toggle(recording),
                .hotkey_down => self.trigger.press(now, recording),
                .hotkey_up => self.trigger.release(now, recording),
            });
        }
    }

    fn pollUiRequests(self: *Daemon) !void {
        if (self.request_toggle) {
            self.request_toggle = false;
            self.applyAction(self.trigger.toggle(self.isRecording()));
        }
        if (self.request_toggle_hud) {
            self.request_toggle_hud = false;
            // Tray left-click: expand the pill, or put the open panel away.
            if (self.hud) |hud| {
                if (self.hudVisible() and c_hud.talkies_hud_is_expanded(hud) != 0) {
                    if (self.phase.isQuiescent() and self.phase != .yap) self.dismissResult();
                } else {
                    self.expandHud();
                }
            }
        }
        if (self.request_expand_hud) {
            self.request_expand_hud = false;
            self.expandHud();
        }
        if (self.request_dismiss) {
            self.request_dismiss = false;
            self.dismissResult();
        }
        if (self.request_settings) {
            self.request_settings = false;
            try self.openSettings();
        }
    }

    fn onHudRecord(user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        self.request_toggle = true;
    }

    /// The user put the panel away (pointer left it).
    fn onHudDismiss(user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        self.request_dismiss = true;
    }

    /// A finished result was put away: back to idle (and the pill).
    fn dismissResult(self: *Daemon) void {
        switch (self.phase) {
            .complete, .failed => self.enter(.idle, null),
            .idle => self.collapseHud(),
            else => {},
        }
    }

    fn onTray(action: c_tray.TalkiesTrayAction, user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        switch (action) {
            c_tray.TALKIES_TRAY_ACTIVATE => self.request_toggle_hud = true,
            c_tray.TALKIES_TRAY_OPEN => self.request_expand_hud = true,
            c_tray.TALKIES_TRAY_TOGGLE_RECORD => self.request_toggle = true,
            c_tray.TALKIES_TRAY_SETTINGS => self.request_settings = true,
            c_tray.TALKIES_TRAY_QUIT => self.quit = true,
            else => {},
        }
    }

    fn onStatusSettings(user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        self.request_settings = true;
    }

    // -----------------------------------------------------------------
    // S1-mini model management
    // -----------------------------------------------------------------

    fn s1Store(self: *Daemon) cleanup.ModelStore {
        return .{ .allocator = self.allocator, .quiet = true };
    }

    fn s1Ready(self: *Daemon) bool {
        return @as(S1State, @enumFromInt(self.s1_state.load(.acquire))) == .ready;
    }

    fn refreshS1State(self: *Daemon) void {
        if (self.s1_thread != null) return;
        const state: S1State = if (self.s1Store().isInstalled()) .ready else .missing;
        self.s1_state.store(@intFromEnum(state), .release);
        self.pushS1State();
    }

    fn pushS1State(self: *Daemon) void {
        const win = self.settings_win orelse return;
        const state: S1State = @enumFromInt(self.s1_state.load(.acquire));
        const fraction: f64 = if (state == .downloading)
            @as(f64, @floatFromInt(self.s1Store().downloadedBytes())) / @as(f64, @floatFromInt(cleanup.model_size))
        else
            0;
        c_settings.talkies_settings_window_set_s1_state(win, @intFromEnum(state), std.math.clamp(fraction, 0, 1), null);
    }

    fn startS1Download(self: *Daemon) void {
        if (self.s1_thread != null) return;
        self.s1_state.store(@intFromEnum(S1State.downloading), .release);
        self.s1_thread = std.Thread.spawn(.{}, s1DownloadThread, .{self}) catch |err| {
            self.log(.err, "Could not start S1-mini download: {}", .{err});
            self.s1_state.store(@intFromEnum(S1State.failed), .release);
            self.pushS1State();
            return;
        };
        self.log(.info, "Downloading S1-mini model...", .{});
        self.pushS1State();
        self.s1_timer = c_loop.talkies_loop_timeout(400, onS1Progress, self);
    }

    fn s1DownloadThread(self: *Daemon) void {
        const path = self.s1Store().ensureAvailable() catch |err| {
            utils.logError("S1-mini download failed: {}", .{err});
            self.s1_state.store(@intFromEnum(S1State.failed), .release);
            self.wake();
            return;
        };
        self.allocator.free(path);
        self.s1_state.store(@intFromEnum(S1State.ready), .release);
        self.wake();
    }

    fn onS1Progress(user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return 0));
        self.pushS1State();
        if (self.s1_thread == null) {
            self.s1_timer = 0;
            return 0;
        }
        return 1;
    }

    fn collectS1Download(self: *Daemon) void {
        const thread = self.s1_thread orelse return;
        const state: S1State = @enumFromInt(self.s1_state.load(.acquire));
        if (state == .downloading) return;
        thread.join();
        self.s1_thread = null;
        c_loop.talkies_loop_remove(self.s1_timer);
        self.s1_timer = 0;
        self.log(if (state == .ready) .info else .err, "S1-mini download {s}", .{if (state == .ready) "complete" else "failed"});
        self.pushS1State();
    }

    fn onS1Download(user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        self.startS1Download();
    }

    fn onS1Remove(user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        if (!self.phase.isQuiescent() or self.s1_thread != null) return;
        // Release the loaded weights before deleting them.
        self.cleanup_service.deinit();
        self.s1Store().remove() catch |err| self.log(.err, "Could not remove S1-mini: {}", .{err});
        self.refreshS1State();
    }

    // -----------------------------------------------------------------
    // Settings
    // -----------------------------------------------------------------

    fn openSettings(self: *Daemon) !void {
        if (self.settings_win == null) {
            const path = try config.Config.configPath(self.allocator);
            defer self.allocator.free(path);
            const path_z = try utils.dupeZ(self.allocator, path);
            defer self.allocator.free(path_z);
            self.settings_win = c_settings.talkies_settings_window_new(&mode_names, &mode_descriptions, path_z.ptr) orelse
                return error.SettingsWindowFailed;
            c_settings.talkies_settings_window_set_callbacks(self.settings_win, onSettingsSave, onSettingsRefresh, self);
            c_settings.talkies_settings_window_set_s1_callbacks(self.settings_win, onS1Download, onS1Remove);
        }
        const win = self.settings_win.?;
        self.loadAudioDevices(win);

        var data: c_settings.TalkiesSettingsData = std.mem.zeroes(c_settings.TalkiesSettingsData);
        settingsFromConfig(self.pending_cfg orelse self.cfg, &data);
        c_settings.talkies_settings_window_present(win, &data);
        self.refreshS1State();
        self.refreshHealth();

        // Like macOS, check the selected server as the settings open.
        switch ((self.pending_cfg orelse self.cfg).enhancer) {
            .ollama => self.refreshModels(c_settings.TALKIES_SERVER_OLLAMA, self.cfg.ollama_host),
            .lm_studio => self.refreshModels(c_settings.TALKIES_SERVER_LM_STUDIO, self.cfg.lm_studio_endpoint),
            .none, .s1_mini => {},
        }
    }

    fn loadAudioDevices(self: *Daemon, win: *c_settings.TalkiesSettingsWindow) void {
        var sources = listAudioSources(self.allocator) catch |err| {
            utils.logError("Could not list audio sources: {}", .{err});
            return;
        };
        defer sources.deinit();
        c_settings.talkies_settings_window_set_audio_devices(win, sources.names.items.ptr, sources.descriptions.items.ptr, @intCast(sources.names.items.len));
    }

    fn refreshModels(self: *Daemon, server: c_settings.TalkiesServer, base_url: []const u8) void {
        const win = self.settings_win orelse return;
        const kind: enhance.Server = if (server == c_settings.TALKIES_SERVER_OLLAMA) .ollama else .lm_studio;
        const label = if (kind == .ollama) "Ollama" else "LM Studio";

        var models = enhance.listModels(self.allocator, kind, base_url) catch |err| {
            var buf: [128]u8 = undefined;
            const status = switch (err) {
                error.NonLocalEndpoint => bufPrintZ(&buf, "Only local servers are allowed", .{}),
                else => bufPrintZ(&buf, "{s} is not running", .{label}),
            } catch @as([:0]const u8, "Unavailable");
            c_settings.talkies_settings_window_set_models(win, server, null, 0, status.ptr);
            if (self.status_win) |sw| if (kind == .ollama) sw.setOllamaConnected(false);
            return;
        };
        defer models.deinit();

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const names_z = arena.allocator().alloc([*:0]const u8, models.names.len) catch return;
        for (models.names, 0..) |name, i| {
            names_z[i] = (utils.dupeZ(arena.allocator(), name) catch return).ptr;
        }
        var buf: [128]u8 = undefined;
        const status = bufPrintZ(&buf, "Ready · {d} model{s}", .{ models.names.len, if (models.names.len == 1) "" else "s" }) catch @as([:0]const u8, "Ready");
        c_settings.talkies_settings_window_set_models(win, server, @ptrCast(names_z.ptr), @intCast(names_z.len), status.ptr);
        if (self.status_win) |sw| if (kind == .ollama) sw.setOllamaConnected(true);
    }

    fn onSettingsRefresh(server: c_settings.TalkiesServer, base_url: [*c]const u8, user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        self.refreshModels(server, std.mem.span(base_url));
    }

    fn onSettingsSave(data: [*c]const c_settings.TalkiesSettingsData, user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        if (data == null) return;
        self.saveSettings(@ptrCast(data)) catch |err| {
            utils.logError("Saving settings failed: {}", .{err});
        };
    }

    fn saveSettings(self: *Daemon, data: *const c_settings.TalkiesSettingsData) !void {
        var next = config.Config.init(self.allocator);
        errdefer next.deinit();
        try copyConfig(&next, self.pending_cfg orelse self.cfg);
        try configFromSettings(&next, data);
        try next.save();

        // Picking S1-mini without the model starts the download right away.
        if (next.enhancer == .s1_mini and !self.s1Ready()) self.startS1Download();

        if (self.pending_cfg) |*old| old.deinit();
        self.pending_cfg = next;
        try self.applyPendingConfig();
    }

    /// Swap in saved settings once no worker reads the config.
    fn applyPendingConfig(self: *Daemon) !void {
        if (!self.phase.isQuiescent() or self.job != null or self.capture != null) return;
        const next = self.pending_cfg orelse return;
        self.pending_cfg = null;

        const model_changed = !std.mem.eql(u8, next.model, self.cfg.model);
        const threads_changed = next.threads != self.cfg.threads;
        self.cfg.deinit();
        self.cfg = next;
        self.trigger = trigger_mod.Trigger.init(self.cfg.push_to_talk_threshold);
        self.whisper_service.configure(self.cfg.language, self.cfg.threads);
        if (threads_changed) {
            self.cleanup_service.deinit();
            self.cleanup_service = .{ .allocator = self.allocator, .threads = self.cfg.threads };
        }
        if (self.hud) |hud| c_hud.talkies_hud_set_mini(hud, @intFromBool(self.cfg.mini_window));
        if (!self.cfg.show_hud) self.hideHud() else if (self.phase == .idle) self.collapseHud();
        if (model_changed) try self.loadWhisperModel(true);
        self.log(.info, "Settings applied", .{});
        self.refreshHealth();
    }

    fn loadWhisperModel(self: *Daemon, show_progress: bool) !void {
        self.enter(.starting, null);
        if (show_progress) self.expandHud();
        pumpGtk();
        if (self.status_win) |win| win.setModel(self.cfg.model);
        self.whisper_service.loadModel(self.cfg.model) catch |err| {
            self.log(.err, "Could not load model '{s}': {}", .{ self.cfg.model, err });
            self.showError("Could not load Whisper model");
            return err;
        };
        self.log(.info, "Model '{s}' loaded", .{self.cfg.model});
        self.enter(.idle, null);
    }

    // -----------------------------------------------------------------
    // YAP mode (ported from the previous Wayland-only loop)
    // -----------------------------------------------------------------

    fn handleYapTranscript(self: *Daemon, text: []const u8) !void {
        if (self.yap_sb) |sb| {
            const appended = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ sb.yapping, text });
            self.allocator.free(sb.yapping);
            sb.yapping = appended;
            if (self.yap_win) |win| win.updateDisplay() catch |err| utils.logError("YAP display: {}", .{err});
            self.enter(.yap, null);
            return;
        }
        if (self.startYapSession(text)) {
            self.enter(.yap, null);
        } else {
            // YAP unavailable: behave like normal dictation.
            self.output(text);
            self.enterResult(.complete, null);
        }
    }

    /// Returns false if YAP could not start and the caller should paste.
    fn startYapSession(self: *Daemon, text: []const u8) bool {
        const allocator = self.allocator;
        const sm = allocator.create(yap_sessions.SessionManager) catch return false;
        sm.* = yap_sessions.SessionManager.init(allocator) catch |err| {
            allocator.destroy(sm);
            utils.logError("YAP session manager failed: {}", .{err});
            return false;
        };
        self.yap_session_manager = sm;

        self.yap_session_id = sm.createSession(text, null, self.cfg.yap_llm_model, self.cfg.yap_ollama_url) catch |err| {
            utils.logError("YAP session creation failed: {}", .{err});
            self.endYapSession();
            return false;
        };

        const sb = allocator.create(yap_sandbox.Sandbox) catch {
            self.endYapSession();
            return false;
        };
        sb.* = yap_sandbox.Sandbox.init(allocator, text, null, self.cfg.yap_ollama_url, self.cfg.yap_system_prompt, utils.io()) catch |err| {
            allocator.destroy(sb);
            utils.logError("YAP sandbox creation failed: {}", .{err});
            self.abandonYap();
            return false;
        };
        self.yap_sb = sb;

        const refined = sb.refineInitial(self.cfg.yap_llm_model) catch |err| {
            utils.logError("YAP refinement failed: {}", .{err});
            self.abandonYap();
            return false;
        };
        utils.log("YAP refined ({d} chars)", .{refined.len});
        sm.saveSandbox(self.yap_session_id.?, sb) catch |err| utils.logError("YAP save: {}", .{err});

        self.yap_win = yap_window.YapWindow.create(allocator, sb, self.state) catch |err| {
            utils.logError("YAP window creation failed: {}", .{err});
            self.abandonYap();
            return false;
        };
        self.yap_win.?.show();
        return true;
    }

    fn abandonYap(self: *Daemon) void {
        if (self.yap_session_id) |sid| {
            if (self.yap_session_manager) |sm| sm.abandonSession(sid) catch |err| utils.logError("YAP abandon: {}", .{err});
        }
        self.endYapSession();
    }

    fn endYapSession(self: *Daemon) void {
        if (self.yap_win) |win| win.destroy();
        self.yap_win = null;
        if (self.yap_sb) |sb| {
            sb.deinit();
            self.allocator.destroy(sb);
        }
        self.yap_sb = null;
        if (self.yap_session_manager) |sm| {
            sm.deinit();
            self.allocator.destroy(sm);
        }
        self.yap_session_manager = null;
        self.yap_session_id = null;
    }

    /// Insert or copy text on the main thread (YAP accept/cancel).
    fn output(self: *Daemon, text: []const u8) void {
        if (text.len == 0) return;
        if (self.cfg.auto_paste) {
            self.inserter.insertTextAtCursor(text, self.cfg.paste_keybind, self.cfg.restore_clipboard) catch |err| {
                self.log(.err, "Could not insert text: {}", .{err});
            };
        } else {
            var clip = clipboard.Clipboard.init(self.allocator);
            defer clip.deinit();
            clip.copy(text) catch |err| self.log(.err, "Could not copy text: {}", .{err});
        }
    }

    fn pollYap(self: *Daemon) !void {
        const win = self.yap_win orelse return;
        const sb = self.yap_sb orelse return;
        const command = self.state.getYapCommand() orelse return;
        self.state.clearYapCommand();
        // Inserting while a worker also inserts would interleave clipboards.
        if (self.job != null and (command == .accept or command == .cancel)) {
            try self.state.setYapCommand(command, null);
            return;
        }

        switch (command) {
            .accept, .cancel => {
                const source = if (command == .accept) sb.getCurrentRefinement() else sb.yapping;
                // Copy before the sandbox that owns `source` is freed.
                const final_text = try self.allocator.dupe(u8, source);
                defer self.allocator.free(final_text);
                if (self.yap_session_id) |sid| {
                    if (self.yap_session_manager) |sm| {
                        if (command == .accept) {
                            sm.completeSession(sid, final_text) catch |err| utils.logError("YAP complete: {}", .{err});
                        } else {
                            sm.abandonSession(sid) catch |err| utils.logError("YAP abandon: {}", .{err});
                        }
                    }
                }
                self.endYapSession();
                self.output(final_text);
                self.rememberTranscript(final_text);
                if (self.phase == .yap) self.enter(.idle, null);
            },
            .request_clarification => try self.yapClarify(win, sb),
            .refine => try self.yapRefine(win, sb),
            .append_transcription => {},
        }
    }

    fn yapClarify(self: *Daemon, win: *yap_window.YapWindow, sb: *yap_sandbox.Sandbox) !void {
        const allocator = self.allocator;
        const questions = sb.generateClarificationQuestions(self.cfg.yap_llm_model) catch |err| {
            utils.logError("Clarification failed, refining directly: {}", .{err});
            try self.state.setYapCommand(.refine, null);
            return;
        };
        try self.state.setClarificationQuestions(questions);

        const c_questions = try allocator.alloc(yap_window.c.YapClarificationQuestion, questions.len);
        defer allocator.free(c_questions);
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        for (questions, 0..) |q, i| {
            const opts = try arena.allocator().alloc([*c]const u8, q.options.len);
            for (q.options, 0..) |opt, j| opts[j] = opt.ptr;
            c_questions[i] = .{
                .id = q.id.ptr,
                .question_text = q.text.ptr,
                .options = opts.ptr,
                .option_count = @intCast(q.options.len),
            };
        }
        yap_window.c.yap_window_gtk_show_clarification(win.gtk_win, c_questions.ptr, @intCast(questions.len));
        win.clarification_active = true;
    }

    fn yapRefine(self: *Daemon, win: *yap_window.YapWindow, sb: *yap_sandbox.Sandbox) !void {
        const allocator = self.allocator;
        const ctx = self.state.getYapRefineContext();
        defer if (ctx) |c| allocator.free(c);

        const refined = if (sb.getRevisionCount() == 0) blk: {
            const answers = self.state.getClarificationAnswers() catch &[_]daemon_ws.ClarificationAnswer{};
            defer {
                for (answers) |*item| {
                    var mutable_item = item.*;
                    mutable_item.deinit(allocator);
                }
                allocator.free(answers);
            }
            const result = sb.refineInitialWithClarification(self.cfg.yap_llm_model, if (answers.len > 0) answers else null) catch |err| {
                utils.logError("YAP initial refinement failed: {}", .{err});
                return;
            };
            self.state.clearClarificationState();
            break :blk result;
        } else sb.refineAgain(self.cfg.yap_llm_model, ctx) catch |err| {
            utils.logError("YAP refinement failed: {}", .{err});
            return;
        };

        if (self.yap_session_manager) |sm| {
            if (self.yap_session_id) |sid| sm.saveSandbox(sid, sb) catch |err| utils.logError("YAP save: {}", .{err});
        }
        win.updateDisplay() catch |err| utils.logError("YAP display: {}", .{err});
        self.state.broadcastYapRefined(refined, @intCast(sb.getRevisionCount()), sb.yapping.len) catch |err| utils.logError("broadcast: {}", .{err});
    }

    // -----------------------------------------------------------------
    // Main loop
    // -----------------------------------------------------------------

    /// Everything that can change after an event: drained after every loop
    /// iteration, so state is reconciled exactly when something happened.
    fn tick(self: *Daemon) !void {
        self.pollCommands();
        try self.pollUiRequests();
        self.collectCapture();
        try self.pollJob();
        self.collectS1Download();
        if (self.yap_win != null) try self.pollYap();
    }

    /// Blocks in the GLib main loop until an fd, timer or GTK event fires.
    /// Idle CPU use is zero: there is no polling interval.
    fn loop(self: *Daemon) !void {
        while (!self.quit) {
            c_loop.talkies_loop_iterate(1);
            try self.tick();
        }
        self.log(.info, "Daemon shutting down", .{});
    }
};

fn bufPrintZ(buf: []u8, comptime fmt: []const u8, args: anytype) ![:0]u8 {
    return std.fmt.bufPrintSentinel(buf, fmt, args, 0);
}

fn pumpGtk() void {
    c_gtk.daemon_status_gtk_process_events();
}

// ---------------------------------------------------------------------
// Settings <-> Config
// ---------------------------------------------------------------------

const mode_names: [enhance.Mode.all.len][*c]const u8 = blk: {
    var names: [enhance.Mode.all.len][*c]const u8 = undefined;
    for (enhance.Mode.all, 0..) |mode, i| names[i] = (mode.displayName() ++ "\x00").ptr;
    break :blk names;
};

const mode_descriptions: [enhance.Mode.all.len][*c]const u8 = blk: {
    var descs: [enhance.Mode.all.len][*c]const u8 = undefined;
    for (enhance.Mode.all, 0..) |mode, i| descs[i] = (mode.description() ++ "\x00").ptr;
    break :blk descs;
};

fn putString(buf: []u8, value: []const u8) void {
    const n = @min(value.len, buf.len - 1);
    @memcpy(buf[0..n], value[0..n]);
    buf[n] = 0;
}

fn getString(buf: []const u8) []const u8 {
    return std.mem.sliceTo(buf, 0);
}

fn modeIndex(value: []const u8) c_int {
    return @intCast(@intFromEnum(enhance.Mode.parse(value)));
}

fn modeTag(index: c_int) []const u8 {
    const clamped: usize = @intCast(std.math.clamp(index, 0, @as(c_int, enhance.Mode.all.len - 1)));
    return @tagName(enhance.Mode.all[clamped]);
}

pub fn settingsFromConfig(cfg: config.Config, d: *c_settings.TalkiesSettingsData) void {
    d.push_to_talk_threshold = cfg.push_to_talk_threshold;
    d.show_hud = @intFromBool(cfg.show_hud);
    d.voice_assistant_mode = @intFromBool(cfg.voice_assistant_mode);
    d.insert_text_in_assistant_mode = @intFromBool(cfg.insert_text_in_assistant_mode);
    putString(&d.audio_device, cfg.audio_device);
    putString(&d.model, cfg.model);
    putString(&d.language, cfg.language);
    putString(&d.vocabulary_prompt, cfg.vocabulary_prompt);
    d.enhancer = @intCast(@intFromEnum(cfg.enhancer));

    putString(&d.ollama_host, cfg.ollama_host);
    putString(&d.ollama_model, cfg.ollama_selected_model);
    d.ollama_mode = modeIndex(cfg.ollama_enhancement_mode);
    d.ollama_temperature = cfg.ollama_temperature;
    d.ollama_top_p = cfg.ollama_top_p;
    d.ollama_top_k = @intCast(cfg.ollama_top_k);
    d.ollama_repeat_penalty = cfg.ollama_repeat_penalty;
    d.ollama_context_length = @intCast(cfg.ollama_context_length);
    d.ollama_max_tokens = @intCast(cfg.ollama_max_tokens);
    d.ollama_use_custom_prompt = @intFromBool(cfg.ollama_use_custom_prompt);
    putString(&d.ollama_custom_prompt, cfg.ollama_custom_system_prompt);
    putString(&d.ollama_stop_sequences, cfg.ollama_stop_sequences);

    putString(&d.lm_studio_endpoint, cfg.lm_studio_endpoint);
    putString(&d.lm_studio_model, cfg.lm_studio_selected_model);
    d.lm_studio_mode = modeIndex(cfg.lm_studio_enhancement_mode);
    d.lm_studio_temperature = cfg.lm_studio_temperature;
    d.lm_studio_top_p = cfg.lm_studio_top_p;
    d.lm_studio_max_tokens = @intCast(cfg.lm_studio_max_tokens);

    d.auto_paste = @intFromBool(cfg.auto_paste);
    d.restore_clipboard = @intFromBool(cfg.restore_clipboard);
    putString(&d.paste_keybind, cfg.paste_keybind);
    d.vad_enabled = @intFromBool(cfg.vad_enabled);
    d.vad_mode = cfg.vad_mode;
    d.show_status_gui = @intFromBool(cfg.show_status_gui);
}

fn toU32(value: c_int) u32 {
    return @intCast(@max(value, 0));
}

pub fn configFromSettings(cfg: *config.Config, d: *const c_settings.TalkiesSettingsData) !void {
    cfg.push_to_talk_threshold = d.push_to_talk_threshold;
    cfg.show_hud = d.show_hud != 0;
    cfg.voice_assistant_mode = d.voice_assistant_mode != 0;
    cfg.insert_text_in_assistant_mode = d.insert_text_in_assistant_mode != 0;
    try cfg.setString("audio_device", getString(&d.audio_device));
    if (getString(&d.model).len > 0) try cfg.setString("model", getString(&d.model));
    try cfg.setString("language", getString(&d.language));
    try cfg.setString("vocabulary_prompt", getString(&d.vocabulary_prompt));
    cfg.enhancer = std.enums.fromInt(config.EnhancerProvider, d.enhancer) orelse .none;
    cfg.enhancer_explicit = true;

    try cfg.setString("ollama_host", getString(&d.ollama_host));
    if (getString(&d.ollama_model).len > 0) try cfg.setString("ollama_selected_model", getString(&d.ollama_model));
    try cfg.setString("ollama_enhancement_mode", modeTag(d.ollama_mode));
    cfg.ollama_temperature = d.ollama_temperature;
    cfg.ollama_top_p = d.ollama_top_p;
    cfg.ollama_top_k = toU32(d.ollama_top_k);
    cfg.ollama_repeat_penalty = d.ollama_repeat_penalty;
    cfg.ollama_context_length = toU32(d.ollama_context_length);
    cfg.ollama_max_tokens = toU32(d.ollama_max_tokens);
    cfg.ollama_use_custom_prompt = d.ollama_use_custom_prompt != 0;
    try cfg.setString("ollama_custom_system_prompt", getString(&d.ollama_custom_prompt));
    try cfg.setString("ollama_stop_sequences", getString(&d.ollama_stop_sequences));

    try cfg.setString("lm_studio_endpoint", getString(&d.lm_studio_endpoint));
    try cfg.setString("lm_studio_selected_model", getString(&d.lm_studio_model));
    try cfg.setString("lm_studio_enhancement_mode", modeTag(d.lm_studio_mode));
    cfg.lm_studio_temperature = d.lm_studio_temperature;
    cfg.lm_studio_top_p = d.lm_studio_top_p;
    cfg.lm_studio_max_tokens = toU32(d.lm_studio_max_tokens);

    cfg.auto_paste = d.auto_paste != 0;
    cfg.restore_clipboard = d.restore_clipboard != 0;
    try cfg.setString("paste_keybind", getString(&d.paste_keybind));
    cfg.vad_enabled = d.vad_enabled != 0;
    cfg.vad_mode = @intCast(std.math.clamp(d.vad_mode, 0, 3));
    cfg.show_status_gui = d.show_status_gui != 0;
}

/// Deep-copy every field of `src` into `dst`, with strings owned by dst's arena.
fn copyConfig(dst: *config.Config, src: config.Config) !void {
    const info = @typeInfo(config.Config).@"struct";
    inline for (info.field_names, info.field_types) |name, T| {
        if (comptime std.mem.eql(u8, name, "allocator") or std.mem.eql(u8, name, "arena")) continue;
        if (T == []const u8) {
            try dst.setString(name, @field(src, name));
        } else {
            @field(dst, name) = @field(src, name);
        }
    }
}

const AudioSources = struct {
    arena: std.heap.ArenaAllocator,
    names: std.ArrayList([*c]const u8) = .empty,
    descriptions: std.ArrayList([*c]const u8) = .empty,

    fn deinit(self: *AudioSources) void {
        self.arena.deinit();
    }
};

/// Parse `pactl list sources` into input devices (monitors excluded).
fn listAudioSources(allocator: std.mem.Allocator) !AudioSources {
    const output = try utils.runCapture(allocator, &.{ "pactl", "list", "sources" });
    defer allocator.free(output);
    var result: AudioSources = .{ .arena = std.heap.ArenaAllocator.init(allocator) };
    errdefer result.deinit();
    try parseAudioSources(&result, output);
    return result;
}

fn parseAudioSources(result: *AudioSources, output: []const u8) !void {
    const arena = result.arena.allocator();
    var name: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (std.mem.startsWith(u8, trimmed, "Name: ")) {
            name = trimmed["Name: ".len..];
        } else if (std.mem.startsWith(u8, trimmed, "Description: ")) {
            const n = name orelse continue;
            name = null;
            if (std.mem.endsWith(u8, n, ".monitor")) continue;
            try result.names.append(arena, (try utils.dupeZ(arena, n)).ptr);
            try result.descriptions.append(arena, (try utils.dupeZ(arena, trimmed["Description: ".len..])).ptr);
        }
    }
}

/// Locate the shipped tray icons: <app>/share/icons when installed, or
/// zig-out/share/icons for a development build. Null falls back to stock icons.
fn findIconThemePath(buf: *[std.fs.max_path_bytes:0]u8) ?[:0]const u8 {
    var exe_buf: [std.fs.max_path_bytes]u8 = undefined;
    const rc = std.os.linux.readlink("/proc/self/exe", &exe_buf, exe_buf.len);
    if (std.os.linux.errno(rc) != .SUCCESS) return null;
    const exe_dir = std.fs.path.dirname(exe_buf[0..rc]) orelse return null;
    for ([_][]const u8{ "share/icons", "../share/icons" }) |rel| {
        const dir = std.fmt.bufPrintSentinel(buf, "{s}/{s}", .{ exe_dir, rel }, 0) catch continue;
        var probe_buf: [std.fs.max_path_bytes]u8 = undefined;
        const probe = std.fmt.bufPrint(&probe_buf, "{s}/hicolor/scalable/status/talkies-tray-symbolic.svg", .{dir}) catch continue;
        if (std.Io.Dir.cwd().access(utils.io(), probe, .{})) |_| return dir else |_| {}
    }
    return null;
}

/// Apply Hyprland window rules so the HUD floats, stays on top and never
/// takes focus (GTK4 cannot request this itself on Wayland).
fn applyCompositorRules(allocator: std.mem.Allocator) void {
    if (utils.getEnv("HYPRLAND_INSTANCE_SIGNATURE") == null) return;
    // Top centre, 34px below the top of the usable area (macOS anchors the
    // panel under the menu bar; here, under any top bar).
    var move_buf: [160]u8 = undefined;
    const move_rule = std.fmt.bufPrint(&move_buf, "match:title ^(Talkies Dictation)$, move ((monitor_w-{d})/2) ({d})", .{
        c_hud.TALKIES_HUD_WINDOW_WIDTH,
        hyprlandReservedTop(allocator) + c_hud.TALKIES_HUD_SCREEN_TOP - c_hud.TALKIES_HUD_PANEL_TOP,
    }) catch "match:title ^(Talkies Dictation)$, center true";
    const rules = [_][]const u8{
        "match:title ^(Talkies Dictation)$, float true",
        "match:title ^(Talkies Dictation)$, pin true",
        "match:title ^(Talkies Dictation)$, no_focus true",
        "match:title ^(Talkies Dictation)$, no_initial_focus true",
        "match:title ^(Talkies Dictation)$, border_size 0",
        "match:title ^(Talkies Dictation)$, no_shadow true",
        "match:title ^(Talkies Dictation)$, no_anim true",
        // The panel draws its own translucent glass; blur would fill the
        // transparent margins of the fixed-size window.
        "match:title ^(Talkies Dictation)$, no_blur true",
        // It never takes focus, so it would otherwise be dimmed as inactive.
        "match:title ^(Talkies Dictation)$, no_dim true",
        // Inactive-window opacity would fade the glass (it never has focus).
        "match:title ^(Talkies Dictation)$, opacity 1.0 override 1.0 override",
        move_rule,
        // Settings is a compact dialog (macOS: 600x500), not a tiled pane.
        "match:title ^(Talkies Settings)$, float true",
        "match:title ^(Talkies Settings)$, size 680 560",
        "match:title ^(Talkies Settings)$, center true",
    };
    for (rules) |rule| {
        utils.runQuiet(&.{ "hyprctl", "keyword", "windowrule", rule }) catch |err| {
            utils.logError("hyprctl rule '{s}' failed: {} (see README for manual rules)", .{ rule, err });
        };
    }
}

/// Height of the bars reserved at the top of the focused Hyprland monitor
/// (0 if unknown).
fn hyprlandReservedTop(allocator: std.mem.Allocator) i64 {
    const output = utils.runCapture(allocator, &.{ "hyprctl", "-j", "monitors" }) catch |err| {
        utils.logError("hyprctl monitors failed: {}", .{err});
        return 0;
    };
    defer allocator.free(output);
    return parseReservedTop(allocator, output) catch |err| {
        utils.logError("Could not read Hyprland monitors: {}", .{err});
        return 0;
    };
}

fn parseReservedTop(allocator: std.mem.Allocator, json: []const u8) !i64 {
    const Monitor = struct { focused: bool = false, reserved: []const i64 = &.{} };
    const parsed = try std.json.parseFromSlice([]const Monitor, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var top: i64 = 0;
    for (parsed.value) |m| {
        if (m.reserved.len < 2) continue;
        if (m.focused) return m.reserved[1];
        top = @max(top, m.reserved[1]);
    }
    return top;
}

test "reserved top comes from the focused Hyprland monitor" {
    const json =
        \\[{"name":"HDMI-A-1","focused":false,"reserved":[0,30,0,0]},
        \\ {"name":"DP-3","focused":true,"reserved":[0,59,0,0],"scale":1}]
    ;
    try std.testing.expectEqual(@as(i64, 59), try parseReservedTop(std.testing.allocator, json));
    try std.testing.expectEqual(@as(i64, 0), try parseReservedTop(std.testing.allocator, "[]"));
}

// ---------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------

pub fn run(allocator: std.mem.Allocator) !void {
    utils.log("Starting daemon...", .{});

    const ws_port = wsPort();
    var ws_server = websocket.Server.init(allocator, ws_port) catch |err| switch (err) {
        error.AddressInUse => {
            utils.logError("Another Talkies daemon is already running (port {d} in use). " ++
                "Stop it first, or set TALKIES_WS_PORT for a second instance.", .{ws_port});
            return error.AlreadyRunning;
        },
        else => return err,
    };
    defer ws_server.deinit();
    var state = daemon_ws.DaemonState.init(allocator, &ws_server);

    const efd_rc = std.os.linux.eventfd(0, std.os.linux.EFD.NONBLOCK | std.os.linux.EFD.CLOEXEC);
    if (std.os.linux.errno(efd_rc) != .SUCCESS) return error.EventFdFailed;

    var daemon = Daemon{
        .allocator = allocator,
        .cfg = config.Config.init(allocator),
        .recording_path = try utils.privateRuntimePath(allocator, "recording.wav"),
        .vad_path = try utils.privateRuntimePath(allocator, "recording-vad.wav"),
        .whisper_service = whisper.WhisperService.init(allocator),
        .cleanup_service = .{ .allocator = allocator },
        .inserter = input.TextInserter.init(allocator),
        .recorder = audio.AudioRecorder.init(allocator),
        .ws_server = &ws_server,
        .state = &state,
        .wake_fd = @intCast(efd_rc),
        .trigger = undefined,
        .hotkey_name = "Right Alt",
    };
    defer daemon.deinit();

    try daemon.cfg.load();
    daemon.cleanup_service.threads = daemon.cfg.threads;
    daemon.whisper_service.configure(daemon.cfg.language, daemon.cfg.threads);
    daemon.trigger = trigger_mod.Trigger.init(daemon.cfg.push_to_talk_threshold);
    const platform = daemon.cfg.getEffectivePlatform();
    const is_wayland = std.mem.eql(u8, platform, "wayland");

    // Hotkey sources. Wayland forbids global grabs, so read Right Alt from
    // the keyboards directly when permitted (input group); compositor
    // bindings over WebSocket keep working either way.
    if (is_wayland) {
        daemon.evdev = evdev_hotkey.Listener.open();
        if (daemon.evdev.count == 0) {
            daemon.hotkey_name = "your Talkies hotkey";
            utils.log("Right Alt unavailable on Wayland without /dev/input access; use scripts/talkies-hotkey.sh", .{});
        }
    } else {
        daemon.hotkey_listener = hotkey.HotkeyListener.init(allocator);
        daemon.hotkey_listener.?.start() catch |err| {
            utils.logError("X11 hotkey unavailable: {}", .{err});
            daemon.hotkey_listener.?.deinit();
            daemon.hotkey_listener = null;
        };
    }

    // UI (all optional: the daemon keeps working headless)
    applyCompositorRules(allocator);
    daemon.hud = c_hud.talkies_hud_new();
    if (daemon.hud) |hud| {
        c_hud.talkies_hud_set_hotkey_name(hud, daemon.hotkey_name.ptr);
        c_hud.talkies_hud_set_record_callback(hud, Daemon.onHudRecord, &daemon);
        c_hud.talkies_hud_set_dismiss_callback(hud, Daemon.onHudDismiss, &daemon);
        c_hud.talkies_hud_set_mini(hud, @intFromBool(daemon.cfg.mini_window));
    }
    if (daemon.cfg.show_status_gui) {
        daemon.status_win = daemon_status_window.DaemonStatusWindow.create(allocator) catch |err| blk: {
            utils.logError("Status window unavailable: {}", .{err});
            break :blk null;
        };
        if (daemon.status_win) |win| {
            win.show();
            win.setPlatform(platform);
            win.setYapEnabled(daemon.cfg.yap_mode_enabled);
            c_gtk.daemon_status_window_set_settings_callback(win.gtk_win, Daemon.onStatusSettings, &daemon);
        }
    }
    var icon_dir_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const icon_dir = findIconThemePath(&icon_dir_buf);
    daemon.tray = c_tray.talkies_tray_new(Daemon.onTray, &daemon, if (icon_dir) |d| d.ptr else null);
    if (daemon.tray == null) utils.log("System tray unavailable (no session bus)", .{});

    // Event sources for the blocking main loop.
    state.wake_fn = Daemon.wakeOpaque;
    state.wake_ctx = &daemon;
    _ = c_loop.talkies_loop_watch_fd(daemon.wake_fd, Daemon.onWake, &daemon);
    if (daemon.hotkey_listener) |*listener| {
        _ = c_loop.talkies_loop_watch_fd(listener.fd(), Daemon.onX11Readable, &daemon);
    }
    for (daemon.evdev.devices()) |fd| _ = c_loop.talkies_loop_watch_fd(fd, Daemon.onEvdevReadable, &daemon);
    if (daemon.tray) |t| {
        const fd = c_tray.talkies_tray_get_fd(t);
        if (fd >= 0) _ = c_loop.talkies_loop_watch_fd(fd, Daemon.onTrayReadable, &daemon);
    }
    daemon.refreshS1State();

    const ws_thread = try std.Thread.spawn(.{}, struct {
        fn serve(server: *websocket.Server, st: *daemon_ws.DaemonState) void {
            server.start(struct {
                fn onMessage(alloc: std.mem.Allocator, msg: []const u8, s: *daemon_ws.DaemonState) !void {
                    try daemon_ws.handleMessage(alloc, msg, s);
                }
            }.onMessage, st) catch |err| utils.logError("WebSocket server stopped: {}", .{err});
        }
    }.serve, .{ &ws_server, &state });
    // The accept loop blocks forever; the process exits with the main loop.
    ws_thread.detach();

    try daemon.loadWhisperModel(false);
    daemon.refreshHealth();
    if (daemon.health_report) |*report| {
        for (report.checks.items) |check| {
            if (check.level != .ok) utils.log("{s}: {s}. {s}", .{ check.title, check.detail, check.fix });
        }
    }

    std.debug.print(
        \\Talkies daemon ready
        \\  Platform: {s}
        \\  Hotkey:   {s}
        \\  Enhancer: {s}
        \\  WebSocket: ws://127.0.0.1:{d}
        \\
    , .{
        platform,
        if (daemon.hotkey_listener != null or daemon.evdev.count > 0) "Right Alt (hold = push-to-talk, tap = toggle)" else "compositor binding -> scripts/talkies-hotkey.sh down|up",
        daemon.cfg.enhancer.displayName(),
        ws_port,
    });
    if (build_options.x11 == false and !is_wayland) utils.log("Built without X11 support", .{});

    try daemon.loop();
}

test "level normalization matches the macOS dB meter" {
    try std.testing.expectEqual(@as(f32, 0), normalizeLevel(0));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), normalizeLevel(1.0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), normalizeLevel(0.0316228), 0.0001); // -30dB is the midpoint
    try std.testing.expectApproxEqAbs(@as(f32, 0), normalizeLevel(0.001), 0.0001); // -60dB floor
    try std.testing.expectEqual(@as(f32, 0), normalizeLevel(0.0000001));
}

test "settings round trip through the C struct" {
    const allocator = std.testing.allocator;
    var original = config.Config.init(allocator);
    defer original.deinit();
    original.enhancer = .ollama;
    original.ollama_top_k = 17;
    try original.setString("ollama_enhancement_mode", "Concise & Professional");
    try original.setString("audio_device", "alsa_input.usb-mic");

    var data = std.mem.zeroes(c_settings.TalkiesSettingsData);
    settingsFromConfig(original, &data);

    var restored = config.Config.init(allocator);
    defer restored.deinit();
    try configFromSettings(&restored, &data);

    try std.testing.expectEqual(config.EnhancerProvider.ollama, restored.enhancer);
    try std.testing.expectEqual(@as(u32, 17), restored.ollama_top_k);
    try std.testing.expectEqualStrings("concise", restored.ollama_enhancement_mode);
    try std.testing.expectEqualStrings("alsa_input.usb-mic", restored.audio_device);
}

test "pactl source parsing skips monitors" {
    var result: AudioSources = .{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator) };
    defer result.deinit();
    try parseAudioSources(&result,
        \\Source #1
        \\    Name: alsa_output.pci.monitor
        \\    Description: Monitor of Speakers
        \\Source #2
        \\    Name: alsa_input.usb-mic
        \\    Description: USB Microphone
    );
    try std.testing.expectEqual(@as(usize, 1), result.names.items.len);
    try std.testing.expectEqualStrings("USB Microphone", std.mem.span(result.descriptions.items[0]));
}
