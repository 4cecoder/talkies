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
const utils = @import("utils.zig");
const config = @import("config.zig");
const audio = @import("audio.zig");
const whisper = @import("whisper.zig");
const cleanup = @import("cleanup.zig");
const enhance = @import("enhance.zig");
const input = @import("input.zig");
const clipboard = @import("clipboard.zig");
const hotkey = @import("hotkey.zig");
const websocket = @import("websocket.zig");
const daemon_ws = @import("daemon_ws.zig");
const daemon_status_window = @import("daemon_status_window.zig");
const audio_processing = @import("audio_processing.zig");
const vad = @import("vad.zig");
const yap_sandbox = @import("yap_sandbox.zig");
const yap_sessions = @import("yap_sessions.zig");
const yap_window = @import("yap_window.zig");
const trigger_mod = @import("trigger.zig");
const build_options = @import("build_options");

const c_hud = @import("c_hud");
const c_settings = @import("c_settings");
const c_tray = @import("c_tray");
const c_gtk = @import("c_daemon_status");

const recording_path = "/tmp/talkies-recording.wav";
const vad_trimmed_path = "/tmp/talkies-recording-vad.wav";
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
const tail_ms: i64 = 350;
/// macOS hides the window 1.5s after "Done!".
const hide_after_complete_ms: i64 = 1500;
const hide_after_error_ms: i64 = 3000;
const level_broadcast_interval_ms: i64 = 50;
const chunks_per_iteration = 5; // 5 x 4ms PulseAudio reads per loop pass

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
        };
    }
};

comptime {
    std.debug.assert(@intFromEnum(Stage.@"error") == c_hud.TALKIES_HUD_ERROR);
    std.debug.assert(@intFromEnum(Stage.enhancing_lm_studio) == c_hud.TALKIES_HUD_ENHANCING_LM_STUDIO);
}

/// Map an RMS amplitude to the macOS meter scale: dB clamped to -60..0,
/// normalized to 0..1.
pub fn normalizeLevel(rms: f32) f32 {
    if (rms <= 0.000001) return 0;
    const db = 20.0 * std.math.log10(rms);
    return (std.math.clamp(db, -60.0, 0.0) + 60.0) / 60.0;
}

const Outcome = enum { delivered, no_voice, failed, yap };

/// One recording's trip through the pipeline on a worker thread.
const Job = struct {
    daemon: *Daemon,
    stage: std.atomic.Value(u8) = .init(@intFromEnum(Stage.transcribing)),
    done: std.atomic.Value(bool) = .init(false),
    outcome: Outcome = .failed,
    text: ?[]u8 = null,
    error_buf: [160]u8 = undefined,
    error_len: usize = 0,
    duration_ms: i64 = 0,
    /// Snapshot of YAP routing at spawn time (main thread owns yap state).
    route_to_yap: bool = false,
    thread: std.Thread = undefined,

    fn setStage(self: *Job, stage: Stage) void {
        self.stage.store(@intFromEnum(stage), .release);
    }

    fn fail(self: *Job, comptime fmt: []const u8, args: anytype) void {
        const msg = std.fmt.bufPrint(&self.error_buf, fmt, args) catch self.error_buf[0..];
        self.error_len = msg.len;
        self.outcome = .failed;
    }

    fn errorMessage(self: *const Job) []const u8 {
        return self.error_buf[0..self.error_len];
    }

    fn run(self: *Job) void {
        const started = utils.monotonicMilliseconds();
        self.process();
        self.duration_ms = utils.monotonicMilliseconds() - started;
        self.done.store(true, .release);
    }

    fn process(self: *Job) void {
        const d = self.daemon;
        const cfg = &d.cfg;
        const allocator = d.allocator;

        self.setStage(.transcribing);
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
                self.setStage(.cleaning);
                return d.cleanup_service.clean(raw, .{}) catch |err| {
                    utils.logError("S1-mini cleanup failed; keeping raw transcript: {}", .{err});
                    return d.allocator.dupe(u8, raw);
                };
            },
            .ollama, .lm_studio => {
                self.setStage(if (cfg.enhancer == .ollama) .enhancing_ollama else .enhancing_lm_studio);
                return enhance.enhance(d.allocator, cfg, raw) catch |err| {
                    utils.logError("{s} enhancement failed; keeping raw transcript: {}", .{ cfg.enhancer.displayName(), err });
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
                self.fail("Could not insert text: {s}", .{@errorName(err)});
                return;
            };
        } else {
            var clip = clipboard.Clipboard.init(d.allocator);
            defer clip.deinit();
            clip.copy(text) catch |err| {
                self.fail("Could not copy text: {s}", .{@errorName(err)});
                return;
            };
        }
        self.outcome = .delivered;
    }
};

/// Speak text with speech-dispatcher, falling back to espeak-ng
/// (the Linux stand-in for NSSpeechSynthesizer).
fn speak(text: []const u8) void {
    utils.runQuiet(&.{ "spd-say", "--wait", "--", text }) catch {
        utils.runQuiet(&.{ "espeak-ng", "--", text }) catch |err| {
            utils.logError("Voice assistant: no TTS available (install speech-dispatcher or espeak-ng): {}", .{err});
        };
    };
}

pub const Daemon = struct {
    allocator: std.mem.Allocator,
    cfg: config.Config,
    pending_cfg: ?config.Config = null,

    whisper_service: whisper.WhisperService,
    cleanup_service: cleanup.Cleaner,
    inserter: input.TextInserter,
    recorder: audio.AudioRecorder,

    ws_server: *websocket.Server,
    state: *daemon_ws.DaemonState,
    hotkey_listener: ?hotkey.HotkeyListener = null,
    hotkey_name: [:0]const u8,

    hud: ?*c_hud.TalkiesHud = null,
    status_win: ?*daemon_status_window.DaemonStatusWindow = null,
    settings_win: ?*c_settings.TalkiesSettingsWindow = null,
    tray: ?*c_tray.TalkiesTray = null,

    trigger: trigger_mod.Trigger,
    recording: bool = false,
    record_start_ms: i64 = 0,
    stop_deadline_ms: ?i64 = null,
    last_level_broadcast_ms: i64 = 0,

    job: ?*Job = null,
    shown_stage: Stage = .idle,
    hide_at_ms: ?i64 = null,
    last_transcript: ?[:0]u8 = null,

    // UI requests raised from GTK / D-Bus callbacks, handled in the loop.
    request_toggle: bool = false,
    request_toggle_hud: bool = false,
    request_settings: bool = false,
    quit: bool = false,

    // YAP interactive refinement (opt-in, Linux-only)
    yap_active: bool = false,
    yap_win: ?*yap_window.YapWindow = null,
    yap_sb: ?*yap_sandbox.Sandbox = null,
    yap_session_manager: ?*yap_sessions.SessionManager = null,
    yap_session_id: ?i64 = null,

    // -----------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------

    fn deinit(self: *Daemon) void {
        if (self.job) |job| {
            job.thread.join();
            self.freeJob(job);
        }
        self.endYapSession();
        if (self.recording) self.recorder.stopRecording() catch |err| utils.logError("stop recording: {}", .{err});
        if (self.tray) |t| c_tray.talkies_tray_destroy(t);
        if (self.settings_win) |w| c_settings.talkies_settings_window_destroy(w);
        if (self.hud) |h| c_hud.talkies_hud_destroy(h);
        if (self.status_win) |w| w.destroy();
        if (self.hotkey_listener) |*l| l.deinit();
        if (self.last_transcript) |t| self.allocator.free(t);
        if (self.pending_cfg) |*p| p.deinit();
        self.recorder.deinit();
        self.inserter.deinit();
        self.cleanup_service.deinit();
        self.whisper_service.deinit();
        self.cfg.deinit();
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
            const tip = bufPrintZ(&tip_buf, "{s}", .{if (detail) |dtl| dtl else stage.text()}) catch @as([:0]const u8, "Talkies");
            c_tray.talkies_tray_set_status_text(t, tip.ptr);
        }
        self.broadcastStage(stage);
    }

    fn broadcastStage(self: *Daemon, stage: Stage) void {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{{\"type\":\"pipeline_stage\",\"data\":{{\"stage\":\"{s}\"}}}}", .{@tagName(stage)}) catch return;
        self.ws_server.broadcast(msg) catch |err| utils.logError("broadcast stage: {}", .{err});
    }

    fn setWsState(self: *Daemon, state: daemon_ws.State) void {
        self.state.setState(state) catch |err| utils.logError("broadcast state: {}", .{err});
    }

    fn showHud(self: *Daemon) void {
        if (!self.cfg.show_hud) return;
        if (self.hud) |hud| c_hud.talkies_hud_show(hud);
        self.hide_at_ms = null;
    }

    fn hideHud(self: *Daemon) void {
        if (self.hud) |hud| c_hud.talkies_hud_hide(hud);
        self.hide_at_ms = null;
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

    fn isRecording(self: *const Daemon) bool {
        return self.recording and self.stop_deadline_ms == null;
    }

    fn startRecording(self: *Daemon) void {
        if (self.recording) return;
        if (self.job != null) {
            self.log(.warn, "Still processing the previous recording; ignoring start", .{});
            return;
        }
        const device: ?[]const u8 = if (self.cfg.audio_device.len > 0) self.cfg.audio_device else null;
        self.recorder.startRecording(recording_path, device) catch |err| {
            self.log(.err, "Could not start recording: {}", .{err});
            self.showHud();
            self.setStage(.@"error", "Microphone unavailable");
            self.hide_at_ms = utils.monotonicMilliseconds() + hide_after_error_ms;
            self.state.broadcastError("Failed to start recording", "RECORDING_ERROR") catch |e| utils.logError("broadcast: {}", .{e});
            return;
        };
        self.recording = true;
        self.stop_deadline_ms = null;
        self.record_start_ms = utils.monotonicMilliseconds();
        utils.playSound("assets/start-fast.wav");
        self.showHud();
        self.setStage(.recording, null);
        self.setWsState(.recording);
        self.log(.info, "Recording started", .{});
    }

    fn requestStop(self: *Daemon) void {
        if (!self.recording or self.stop_deadline_ms != null) return;
        self.stop_deadline_ms = utils.monotonicMilliseconds() + tail_ms;
    }

    /// Read a few PulseAudio chunks and publish the level. Blocking reads
    /// pace the main loop at ~20ms while recording.
    fn captureAudio(self: *Daemon) void {
        var peak: f32 = 0;
        for (0..chunks_per_iteration) |_| {
            _ = self.recorder.recordChunk() catch |err| {
                self.log(.err, "Recording failed: {}", .{err});
                self.recorder.stopRecording() catch |e| utils.logError("stop recording: {}", .{e});
                self.recording = false;
                self.stop_deadline_ms = null;
                self.setStage(.@"error", "Recording failed");
                self.hide_at_ms = utils.monotonicMilliseconds() + hide_after_error_ms;
                self.setWsState(.idle);
                return;
            };
            peak = @max(peak, self.recorder.getAudioLevel());
        }

        const level = normalizeLevel(peak);
        const now = utils.monotonicMilliseconds();
        if (self.hud) |hud| {
            c_hud.talkies_hud_set_level(hud, level);
            c_hud.talkies_hud_set_elapsed(hud, @as(f64, @floatFromInt(now - self.record_start_ms)) / 1000.0);
        }
        if (now - self.last_level_broadcast_ms >= level_broadcast_interval_ms) {
            self.last_level_broadcast_ms = now;
            self.state.broadcastAudioLevel(level) catch |err| utils.logError("broadcast level: {}", .{err});
        }

        if (self.stop_deadline_ms) |deadline| {
            if (now >= deadline) self.finishRecording();
        }
    }

    fn finishRecording(self: *Daemon) void {
        self.recording = false;
        self.stop_deadline_ms = null;
        self.recorder.stopRecording() catch |err| {
            self.log(.err, "Could not finalize recording: {}", .{err});
            self.setStage(.@"error", "Could not save recording");
            self.hide_at_ms = utils.monotonicMilliseconds() + hide_after_error_ms;
            self.setWsState(.idle);
            return;
        };
        utils.playSound("assets/stop.wav");
        self.setStage(.transcribing, null);
        self.setWsState(.processing);
        self.spawnJob() catch |err| {
            self.log(.err, "Could not start processing: {}", .{err});
            self.setStage(.@"error", "Could not start processing");
            self.hide_at_ms = utils.monotonicMilliseconds() + hide_after_error_ms;
            self.setWsState(.idle);
        };
    }

    fn spawnJob(self: *Daemon) !void {
        const job = try self.allocator.create(Job);
        errdefer self.allocator.destroy(job);
        job.* = .{ .daemon = self, .route_to_yap = self.yap_active or self.cfg.yap_mode_enabled };
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

        std.Io.Dir.deleteFileAbsolute(utils.io(), recording_path) catch |err| utils.logDebug("cleanup recording: {}", .{err});
        std.Io.Dir.deleteFileAbsolute(utils.io(), vad_trimmed_path) catch |err| utils.logDebug("cleanup vad: {}", .{err});

        const now = utils.monotonicMilliseconds();
        switch (job.outcome) {
            .delivered => {
                const text = job.text orelse "";
                self.rememberTranscript(text);
                self.state.broadcastTranscription(text, job.duration_ms) catch |err| utils.logError("broadcast: {}", .{err});
                self.setStage(.complete, null);
                self.hide_at_ms = now + hide_after_complete_ms;
                self.log(.info, "Delivered {d} chars in {d}ms", .{ text.len, job.duration_ms });
                if (self.status_win) |win| win.setLastTranscription(text);
                self.setWsState(.idle);
            },
            .no_voice => {
                self.log(.warn, "No speech detected", .{});
                self.setStage(.idle, null);
                self.hideHud();
                self.setWsState(.idle);
            },
            .failed => {
                self.log(.err, "{s}", .{job.errorMessage()});
                self.setStage(.@"error", job.errorMessage());
                self.hide_at_ms = now + hide_after_error_ms;
                self.state.broadcastError(job.errorMessage(), "PIPELINE_ERROR") catch |err| utils.logError("broadcast: {}", .{err});
                self.setWsState(.idle);
            },
            .yap => {
                const text = job.text orelse "";
                self.rememberTranscript(text);
                self.state.broadcastTranscription(text, job.duration_ms) catch |err| utils.logError("broadcast: {}", .{err});
                self.setStage(.idle, null);
                self.hideHud();
                try self.handleYapTranscript(text);
            },
        }
        try self.applyPendingConfig();
    }

    fn rememberTranscript(self: *Daemon, text: []const u8) void {
        const copy = utils.dupeZ(self.allocator, text) catch return;
        if (self.last_transcript) |old| self.allocator.free(old);
        self.last_transcript = copy;
        if (self.hud) |hud| c_hud.talkies_hud_set_transcript(hud, copy.ptr);
    }

    // -----------------------------------------------------------------
    // Input sources
    // -----------------------------------------------------------------

    fn pollHotkey(self: *Daemon) !void {
        const listener = if (self.hotkey_listener) |*l| l else return;
        while (listener.hasPendingEvents()) {
            const event = try listener.poll() orelse continue;
            const now = utils.monotonicMilliseconds();
            self.applyAction(switch (event) {
                .press => self.trigger.press(now, self.isRecording()),
                .release => self.trigger.release(now, self.isRecording()),
            });
        }
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
            if (self.hud) |hud| {
                if (c_hud.talkies_hud_is_visible(hud) != 0) self.hideHud() else {
                    c_hud.talkies_hud_show(hud);
                    self.hide_at_ms = null;
                }
            }
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

    fn onTray(action: c_tray.TalkiesTrayAction, user_data: ?*anyopaque) callconv(.c) void {
        const self: *Daemon = @ptrCast(@alignCast(user_data orelse return));
        switch (action) {
            c_tray.TALKIES_TRAY_ACTIVATE, c_tray.TALKIES_TRAY_OPEN => self.request_toggle_hud = true,
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
        }
        const win = self.settings_win.?;
        self.loadAudioDevices(win);

        var data: c_settings.TalkiesSettingsData = std.mem.zeroes(c_settings.TalkiesSettingsData);
        settingsFromConfig(self.pending_cfg orelse self.cfg, &data);
        c_settings.talkies_settings_window_present(win, &data);

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

        if (self.pending_cfg) |*old| old.deinit();
        self.pending_cfg = next;
        try self.applyPendingConfig();
    }

    /// Swap in saved settings once no worker reads the config.
    fn applyPendingConfig(self: *Daemon) !void {
        if (self.job != null or self.recording) return;
        const next = self.pending_cfg orelse return;
        self.pending_cfg = null;

        const model_changed = !std.mem.eql(u8, next.model, self.cfg.model);
        const threads_changed = next.threads != self.cfg.threads;
        self.cfg.deinit();
        self.cfg = next;
        self.trigger = trigger_mod.Trigger.init(self.cfg.push_to_talk_threshold);
        if (threads_changed) {
            self.cleanup_service.deinit();
            self.cleanup_service = .{ .allocator = self.allocator, .threads = self.cfg.threads };
        }
        if (!self.cfg.show_hud) self.hideHud();
        if (model_changed) try self.loadWhisperModel(true);
        self.log(.info, "Settings applied", .{});
    }

    fn loadWhisperModel(self: *Daemon, show_progress: bool) !void {
        if (show_progress) self.showHud();
        self.setStage(.loading_model, null);
        pumpGtk();
        if (self.status_win) |win| win.setModel(self.cfg.model);
        self.whisper_service.loadModel(self.cfg.model) catch |err| {
            self.log(.err, "Could not load model '{s}': {}", .{ self.cfg.model, err });
            self.setStage(.@"error", "Could not load Whisper model");
            self.hide_at_ms = utils.monotonicMilliseconds() + hide_after_error_ms;
            return err;
        };
        self.log(.info, "Model '{s}' loaded", .{self.cfg.model});
        self.setStage(.idle, null);
        if (show_progress) self.hideHud();
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
            self.setWsState(.yap_refining);
            return;
        }
        if (!self.startYapSession(text)) {
            // YAP unavailable: behave like normal dictation.
            self.output(text);
            self.setWsState(.idle);
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
        self.yap_active = true;
        self.setWsState(.yap_refining);
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
        self.yap_active = false;
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
                self.setWsState(.idle);
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

    fn loop(self: *Daemon) !void {
        while (!self.quit) {
            pumpGtk();
            if (self.tray) |t| c_tray.talkies_tray_process(t);
            try self.pollHotkey();
            self.pollCommands();
            try self.pollUiRequests();

            if (self.recording) {
                self.captureAudio();
            } else {
                utils.sleepNanoseconds(8 * std.time.ns_per_ms);
            }

            try self.pollJob();
            if (self.yap_win != null) try self.pollYap();

            if (self.hide_at_ms) |deadline| {
                if (utils.monotonicMilliseconds() >= deadline and !self.recording and self.job == null) {
                    self.hideHud();
                    self.setStage(.idle, null);
                }
            }
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

/// Apply Hyprland window rules so the HUD floats, stays on top and never
/// takes focus (GTK4 cannot request this itself on Wayland).
fn applyCompositorRules() void {
    if (utils.getEnv("HYPRLAND_INSTANCE_SIGNATURE") == null) return;
    const rules = [_][]const u8{
        "match:title ^(Talkies Dictation)$, float true",
        "match:title ^(Talkies Dictation)$, pin true",
        "match:title ^(Talkies Dictation)$, no_focus true",
        "match:title ^(Talkies Dictation)$, no_initial_focus true",
        "match:title ^(Talkies Dictation)$, border_size 0",
        "match:title ^(Talkies Dictation)$, no_shadow true",
        "match:title ^(Talkies Dictation)$, no_anim true",
        "match:title ^(Talkies Dictation)$, move ((monitor_w-520)/2) ((monitor_h-140)/2-100)",
    };
    for (rules) |rule| {
        utils.runQuiet(&.{ "hyprctl", "keyword", "windowrule", rule }) catch |err| {
            utils.logError("hyprctl rule '{s}' failed: {} (see README for manual rules)", .{ rule, err });
        };
    }
}

// ---------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------

pub fn run(allocator: std.mem.Allocator) !void {
    utils.log("Starting daemon...", .{});

    const ws_port = wsPort();
    var ws_server = try websocket.Server.init(allocator, ws_port);
    defer ws_server.deinit();
    var state = daemon_ws.DaemonState.init(allocator, &ws_server);

    var daemon = Daemon{
        .allocator = allocator,
        .cfg = config.Config.init(allocator),
        .whisper_service = whisper.WhisperService.init(allocator),
        .cleanup_service = .{ .allocator = allocator },
        .inserter = input.TextInserter.init(allocator),
        .recorder = audio.AudioRecorder.init(allocator),
        .ws_server = &ws_server,
        .state = &state,
        .trigger = undefined,
        .hotkey_name = "Right Alt",
    };
    defer daemon.deinit();

    try daemon.cfg.load();
    daemon.cleanup_service.threads = daemon.cfg.threads;
    daemon.trigger = trigger_mod.Trigger.init(daemon.cfg.push_to_talk_threshold);
    const platform = daemon.cfg.getEffectivePlatform();
    const is_wayland = std.mem.eql(u8, platform, "wayland");
    if (is_wayland) daemon.hotkey_name = "your Talkies hotkey";

    // UI (all optional: the daemon keeps working headless)
    applyCompositorRules();
    daemon.hud = c_hud.talkies_hud_new();
    if (daemon.hud) |hud| {
        c_hud.talkies_hud_set_hotkey_name(hud, daemon.hotkey_name.ptr);
        c_hud.talkies_hud_set_record_callback(hud, Daemon.onHudRecord, &daemon);
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
    daemon.tray = c_tray.talkies_tray_new(Daemon.onTray, &daemon);
    if (daemon.tray == null) utils.log("System tray unavailable (no session bus)", .{});

    // Input
    if (!is_wayland) {
        daemon.hotkey_listener = hotkey.HotkeyListener.init(allocator);
        daemon.hotkey_listener.?.start() catch |err| {
            utils.logError("X11 hotkey unavailable: {}", .{err});
            daemon.hotkey_listener.?.deinit();
            daemon.hotkey_listener = null;
        };
    }

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
    daemon.setWsState(.idle);

    std.debug.print(
        \\Talkies daemon ready
        \\  Platform: {s}
        \\  Hotkey:   {s}
        \\  Enhancer: {s}
        \\  WebSocket: ws://127.0.0.1:{d}
        \\
    , .{
        platform,
        if (is_wayland) "compositor binding -> scripts/talkies-hotkey.sh down|up" else "Right Alt (hold = push-to-talk, tap = toggle)",
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
