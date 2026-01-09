const std = @import("std");
const audio = @import("audio.zig");
const whisper = @import("whisper.zig");
const clipboard = @import("clipboard.zig");
const input = @import("input.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");
const hotkey = @import("hotkey.zig");
const websocket = @import("websocket.zig");
const daemon_ws = @import("daemon_ws.zig");
const yap_sandbox = @import("yap_sandbox.zig");
const yap_sessions = @import("yap_sessions.zig");
const yap_window = @import("yap_window.zig");
const daemon_status_window = @import("daemon_status_window.zig");
const vad = @import("vad.zig");
const audio_processing = @import("audio_processing.zig");
// TODO: Re-enable after Ghostty bindings support Zig 0.16 (currently requires 0.15.2)
// const settings_ui = @import("settings_ui.zig");
// const tray = @import("tray.zig");

const Command = enum {
    quick,
    record,
    models_download,
    config_show,
    audio_test,
    audio_list,
    audio_set,
    transcribe_test,
    daemon,
    help,
};

// Global state for daemon tray callbacks
var daemon_should_quit = false;
var daemon_show_settings = false;
var daemon_status_win: ?*daemon_status_window.DaemonStatusWindow = null;

// Tray callbacks
fn onQuitCallback() void {
    daemon_should_quit = true;
}

fn onSettingsCallback() void {
    daemon_show_settings = true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printHelp();
        return;
    }

    const command = parseCommand(args[1]) orelse {
        std.debug.print("Unknown command: {s}\n", .{args[1]});
        try printHelp();
        return;
    };

    switch (command) {
        .quick => try runQuick(allocator),
        .record => try runRecord(allocator),
        .models_download => try runModelsDownload(allocator),
        .config_show => try runConfigShow(allocator),
        .audio_test => try runAudioTest(allocator),
        .audio_list => try runAudioList(allocator),
        .audio_set => try runAudioSet(allocator, args),
        .transcribe_test => try runTranscribeTest(allocator, args),
        .daemon => try runDaemon(allocator),
        .help => try printHelp(),
    }
}

fn parseCommand(arg: []const u8) ?Command {
    const command_map = std.StaticStringMap(Command).initComptime(.{
        .{ "quick", .quick },
        .{ "record", .record },
        .{ "models", .models_download },
        .{ "config", .config_show },
        .{ "audio", .audio_test },
        .{ "audio-list", .audio_list },
        .{ "audio-set", .audio_set },
        .{ "transcribe", .transcribe_test },
        .{ "daemon", .daemon },
        .{ "help", .help },
        .{ "--help", .help },
        .{ "-h", .help },
    });

    return command_map.get(arg);
}

fn runQuick(allocator: std.mem.Allocator) !void {
    utils.log("Starting quick recording workflow...", .{});

    // Load configuration
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    // Initialize services
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();

    var clip = clipboard.Clipboard.init(allocator);
    defer clip.deinit();

    var inserter = input.TextInserter.init(allocator);
    defer inserter.deinit();

    // Create temp file for recording
    const temp_path = "/tmp/talkies_recording.wav";

    // Start recording
    const device = if (cfg.audio_device.len > 0) cfg.audio_device else null;
    try recorder.startRecording(temp_path, device);
    std.debug.print("Recording started... Press Ctrl+C to stop and transcribe\n", .{});

    // Record until interrupted (basic implementation - just 10 seconds for now)
    // TODO: Add proper signal handling for Ctrl+C
    const duration_ms: u64 = 10000;
    const chunk_ms: u64 = 100;
    const iterations = duration_ms / chunk_ms;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        _ = try recorder.recordChunk();

        // Show audio level
        const level = recorder.getAudioLevel();
        const bar_length = @as(usize, @intFromFloat(level * 50.0));

        std.debug.print("\rLevel: [", .{});
        var j: usize = 0;
        while (j < 50) : (j += 1) {
            if (j < bar_length) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("] {d:.2}", .{level});

        std.posix.nanosleep(0, chunk_ms * std.time.ns_per_ms);
    }

    std.debug.print("\n", .{});

    // Stop recording
    try recorder.stopRecording();
    std.debug.print("Recording saved to: {s}\n", .{temp_path});

    // Load whisper model
    std.debug.print("Loading whisper model '{s}'...\n", .{cfg.model});
    try whisper_service.loadModel(cfg.model);

    // Transcribe
    std.debug.print("Transcribing audio...\n", .{});
    const transcription = try whisper_service.transcribe(temp_path);
    defer allocator.free(transcription);

    std.debug.print("\nTranscription:\n{s}\n\n", .{transcription});

    // Handle output based on config
    if (cfg.auto_paste) {
        std.debug.print("Inserting text at cursor...\n", .{});
        try inserter.insertTextAtCursor(transcription, cfg.paste_keybind);
        std.debug.print("Text inserted successfully!\n", .{});
    } else {
        std.debug.print("Copying to clipboard...\n", .{});
        try clip.copy(transcription);
        std.debug.print("Text copied to clipboard!\n", .{});
    }

    // Cleanup temp file
    std.fs.deleteFileAbsolute(temp_path) catch |err| {
        std.debug.print("Warning: Failed to delete temp file: {}\n", .{err});
    };

    std.debug.print("\n✅ Quick workflow complete!\n", .{});
}

fn runRecord(allocator: std.mem.Allocator) !void {
    utils.log("Recording audio...", .{});

    // Load config for audio device
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    // Generate output filename
    const output_path = "recording.wav";

    // Start recording
    const device = if (cfg.audio_device.len > 0) cfg.audio_device else null;
    try recorder.startRecording(output_path, device);
    std.debug.print("Recording started to: {s}\n", .{output_path});
    std.debug.print("Recording for 10 seconds...\n", .{});
    std.debug.print("(Press Ctrl+C to abort, but file won't be saved properly)\n", .{});

    // Record for 10 seconds (signal handling is complex in Zig 0.16)
    const duration_ms: u64 = 10000;
    const chunk_ms: u64 = 100;
    const iterations = duration_ms / chunk_ms;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        _ = try recorder.recordChunk();

        // Show audio level
        const level = recorder.getAudioLevel();
        const bar_length = @as(usize, @intFromFloat(level * 50.0));

        std.debug.print("\rLevel: [", .{});
        var j: usize = 0;
        while (j < 50) : (j += 1) {
            if (j < bar_length) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("] {d:.2}", .{level});

        std.posix.nanosleep(0, chunk_ms * std.time.ns_per_ms);
    }

    std.debug.print("\n", .{});

    // Stop recording
    try recorder.stopRecording();

    std.debug.print("Recording saved to: {s}\n", .{output_path});
    std.debug.print("You can play it with: aplay {s}\n", .{output_path});
}

fn runModelsDownload(allocator: std.mem.Allocator) !void {
    utils.log("Downloading whisper models...", .{});

    // Load config to get model name
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();

    std.debug.print("Downloading whisper model: {s}\n", .{cfg.model});
    std.debug.print("This may take a few minutes...\n", .{});

    try whisper_service.downloadModel(cfg.model);

    std.debug.print("Model downloaded successfully!\n", .{});
    std.debug.print("You can now use 'talkies quick' to start transcribing.\n", .{});
}

fn runConfigShow(allocator: std.mem.Allocator) !void {
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();

    // Load config from disk (creates default if not exists)
    try cfg.load();

    // Validate loaded config
    try cfg.validate();

    // Print configuration
    cfg.print();
}

fn runAudioTest(allocator: std.mem.Allocator) !void {
    utils.log("Testing audio recording (5 seconds)...", .{});

    // Load config for audio device
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    const output_path = "test_recording.wav";

    // Start recording
    const device = if (cfg.audio_device.len > 0) cfg.audio_device else null;
    try recorder.startRecording(output_path, device);
    std.debug.print("Recording started... speak into your microphone\n", .{});

    // Record for 5 seconds, showing audio level
    const duration_ms: u64 = 5000;
    const chunk_ms: u64 = 100;
    const iterations = duration_ms / chunk_ms;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        _ = try recorder.recordChunk();

        // Show audio level as a simple bar
        const level = recorder.getAudioLevel();
        const bar_length = @as(usize, @intFromFloat(level * 50.0));

        std.debug.print("\rLevel: [", .{});
        var j: usize = 0;
        while (j < 50) : (j += 1) {
            if (j < bar_length) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("] {d:.2}", .{level});

        std.posix.nanosleep(0, chunk_ms * std.time.ns_per_ms);
    }

    std.debug.print("\n", .{});

    // Stop recording
    try recorder.stopRecording();

    std.debug.print("Recording saved to: {s}\n", .{output_path});
    std.debug.print("You can play it with: aplay {s}\n", .{output_path});
}

fn runAudioList(allocator: std.mem.Allocator) !void {
    utils.log("Listing audio input devices...", .{});

    // Run pactl list sources short to get all audio sources
    const argv = &[_][]const u8{ "pactl", "list", "sources", "short" };
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = child.stdout orelse return error.NoStdout;

    // Read output
    var output_list = std.ArrayList(u8).empty;
    defer output_list.deinit(allocator);

    var buffer: [4096]u8 = undefined;
    while (true) {
        const n = try stdout.read(&buffer);
        if (n == 0) break;
        try output_list.appendSlice(allocator, buffer[0..n]);
    }

    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) {
        std.debug.print("Error: Failed to list audio devices\n", .{});
        return error.PactlFailed;
    }

    std.debug.print("\n=== Available Input Devices ===\n\n", .{});

    // Parse output and show numbered list
    var lines = std.mem.splitScalar(u8, output_list.items, '\n');
    var index: usize = 1;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        // Parse line format: INDEX NAME DRIVER SAMPLE_SPEC STATE
        var parts = std.mem.splitScalar(u8, line, '\t');

        const idx = parts.next() orelse continue;
        const name = parts.next() orelse continue;
        const driver = parts.next() orelse continue;
        _ = driver; // unused

        // Check if it's an input device (monitor sources are for output recording)
        if (std.mem.indexOf(u8, name, "monitor") != null) {
            continue; // Skip monitor devices
        }

        // Show user-friendly output
        std.debug.print("[{d}] {s}\n", .{ index, name });
        std.debug.print("    Index: {s}\n\n", .{idx});

        index += 1;
    }

    std.debug.print("To use a device, run:\n", .{});
    std.debug.print("  talkies audio-set <device-name>\n\n", .{});
}

fn runAudioSet(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: talkies audio-set <device-name>\n", .{});
        std.debug.print("Run 'talkies audio-list' to see available devices\n", .{});
        return;
    }

    const device_name = args[2];

    utils.log("Setting audio device to: {s}", .{device_name});

    // Load config
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    // Update device
    if (cfg.audio_device_owned) {
        allocator.free(cfg.audio_device);
    }
    cfg.audio_device = try allocator.dupe(u8, device_name);
    cfg.audio_device_owned = true;

    // Save config
    try cfg.save();

    std.debug.print("✅ Audio device updated successfully!\n", .{});
    std.debug.print("Device: {s}\n", .{device_name});
    std.debug.print("\nYou can test it with: talkies audio\n", .{});
}

fn runTranscribeTest(allocator: std.mem.Allocator, args: [][:0]u8) !void {
    // Get audio file from args or use default
    const audio_file = if (args.len > 2) args[2] else "anime_16k.wav";

    utils.log("Testing transcription with {s}...", .{audio_file});

    // Load config to get model name
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    std.debug.print("Loading whisper model '{s}'...\n", .{cfg.model});

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();

    try whisper_service.loadModel(cfg.model);

    std.debug.print("Transcribing {s}...\n", .{audio_file});
    const transcription = try whisper_service.transcribe(audio_file);
    defer allocator.free(transcription);

    std.debug.print("\n=== TRANSCRIPTION ===\n{s}\n=====================\n", .{transcription});
}

fn runDaemon(allocator: std.mem.Allocator) !void {
    utils.log("Starting daemon mode...", .{});

    // Load configuration
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    // Create shared Io instance for HTTP client (YAP mode Ollama calls)
    var io_threaded = std.Io.Threaded.init(allocator);
    defer io_threaded.deinit();
    const io = io_threaded.io();

    // Initialize GTK and create daemon status window (if enabled)
    // GTK init is handled in C layer when first window is created
    if (cfg.show_status_gui) {
        daemon_status_win = daemon_status_window.DaemonStatusWindow.create(allocator) catch |err| blk: {
            utils.log("GTK status window initialization failed: {}, continuing without GUI", .{err});
            std.debug.print("⚠️  GTK status window unavailable (continuing in headless mode)\n", .{});
            break :blk null;
        };

        if (daemon_status_win) |win| {
            win.show();
            win.setState("initializing");
            win.addLog(.info, "Daemon starting...");
            std.debug.print("✓ GTK status window initialized\n", .{});

            // Set up settings callback - show dialog when clicked
            const SettingsContext = struct {
                win: *daemon_status_window.DaemonStatusWindow,
                config_path: [:0]const u8,

                fn callback(ctx_ptr: ?*anyopaque) callconv(.c) void {
                    const ctx = @as(*const @This(), @ptrCast(@alignCast(ctx_ptr.?)));
                    ctx.win.showSettingsDialog(ctx.config_path);
                }
            };

            // Get config path
            const config_dir = try utils.getConfigDir(allocator);
            defer allocator.free(config_dir);
            const config_path = try std.fmt.allocPrint(
                allocator,
                "{s}/config.toml\x00",
                .{config_dir},
            );
            // Note: config_path is leaked intentionally - it needs to live for entire daemon lifetime
            const config_path_z: [:0]const u8 = config_path[0 .. config_path.len - 1 :0];

            const ctx = try allocator.create(SettingsContext);
            ctx.* = .{
                .win = win,
                .config_path = config_path_z,
            };

            win.setSettingsCallback(SettingsContext.callback, ctx);
        }
    }

    // Initialize GTK for YAP mode GUI (if enabled)
    if (cfg.yap_mode_enabled) {
        utils.log("YAP mode enabled - YAP window will be created when needed", .{});
        if (daemon_status_win) |win| {
            win.setYapEnabled(true);
            win.addLog(.info, "YAP mode enabled");
        }
    }

    // TODO: Re-enable GTK settings UI after Ghostty bindings support Zig 0.16
    // Currently blocked: Ghostty's gobject bindings require Zig 0.15.2
    // We're on Zig 0.16.0, which removed @Type builtin
    // var ui = settings_ui.SettingsUI.init(allocator, &cfg);
    // defer ui.deinit();

    // TODO: Re-enable system tray after implementing StatusNotifierItem
    // var system_tray = tray.SystemTray.init(allocator);
    // defer system_tray.deinit();
    // system_tray.setQuitCallback(&onQuitCallback);
    // system_tray.setSettingsCallback(&onSettingsCallback);
    // try system_tray.start();
    // utils.log("System tray initialized", .{});

    // Get effective platform (resolve "auto")
    const platform = cfg.getEffectivePlatform();
    const is_wayland = std.mem.eql(u8, platform, "wayland");

    if (daemon_status_win) |win| {
        win.setPlatform(platform);
        var platform_msg_buf: [128]u8 = undefined;
        const platform_msg = try std.fmt.bufPrint(&platform_msg_buf, "Platform: {s}", .{platform});
        win.addLog(.info, platform_msg);
    }

    std.debug.print("Talkies daemon started\n", .{});
    std.debug.print("Platform: {s} (config: {s})\n", .{ platform, cfg.platform });
    if (is_wayland) {
        std.debug.print("Mode: Compositor hotkey (toggle script)\n", .{});
        std.debug.print("Hotkey: Super+Alt+T to toggle recording\n", .{});
        std.debug.print("(Configure in ~/.config/hypr/hyprland.conf - see README)\n", .{});
    } else {
        std.debug.print("Mode: Daemon with global hotkey\n", .{});
        std.debug.print("Hotkey: Right Alt to start/stop recording\n", .{});
    }
    std.debug.print("Press Ctrl+C to exit daemon\n\n", .{});

    // Initialize services
    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();

    var inserter = input.TextInserter.init(allocator);
    defer inserter.deinit();

    // Load whisper model once at startup
    std.debug.print("Loading whisper model '{s}'...\n", .{cfg.model});

    if (daemon_status_win) |win| {
        var model_msg_buf: [128]u8 = undefined;
        const model_msg = try std.fmt.bufPrint(&model_msg_buf, "Loading model: {s}", .{cfg.model});
        win.addLog(.info, model_msg);
        win.setModel(cfg.model);
    }

    try whisper_service.loadModel(cfg.model);
    std.debug.print("Model loaded. Ready!\n\n", .{});

    if (daemon_status_win) |win| {
        win.addLog(.info, "Model loaded successfully");
        win.setState("idle");
    }

    // In Wayland mode, use WebSocket for real-time communication
    // Daemon handles recording internally (no external script needed)
    if (is_wayland) {
        std.debug.print("Wayland mode: Starting WebSocket daemon on ws://localhost:6789\n", .{});
        std.debug.print("Use the toggle script (Super+Alt+T) to trigger recordings\n\n", .{});

        const recording_file = "/tmp/talkies-recording.wav";

        // Initialize audio recorder
        var recorder = audio.AudioRecorder.init(allocator);
        defer recorder.deinit();

        // Get audio device from config (will be used on each recording)
        const device = if (cfg.audio_device.len > 0) cfg.audio_device else null;

        // Initialize WebSocket server
        var ws_server = try websocket.Server.init(allocator, 6789);
        defer ws_server.deinit();

        var daemon_state = daemon_ws.DaemonState.init(allocator, &ws_server);

        // Start WebSocket server in separate thread
        const WsContext = struct {
            server: *websocket.Server,
            state: *daemon_ws.DaemonState,
        };
        var ws_context = WsContext{
            .server = &ws_server,
            .state = &daemon_state,
        };

        const ws_thread = try std.Thread.spawn(.{}, struct {
            fn run(ctx: *WsContext) !void {
                try ctx.server.start(struct {
                    fn onMessage(alloc: std.mem.Allocator, msg: []const u8, state: *daemon_ws.DaemonState) !void {
                        try daemon_ws.handleMessage(alloc, msg, state);
                    }
                }.onMessage, ctx.state);
            }
        }.run, .{&ws_context});
        defer ws_thread.join();

        // Set initial state to idle
        try daemon_state.setState(.idle);

        // Clean up state file from previous run
        std.fs.deleteFileAbsolute("/tmp/talkies-state") catch {};

        std.debug.print("WebSocket server ready!\n\n", .{});

        var last_state = daemon_ws.State.idle;

        // YAP mode persistent state (outside main loop)
        var yap_win: ?*yap_window.YapWindow = null;
        var yap_sb: ?*yap_sandbox.Sandbox = null;
        var yap_session_manager: ?*yap_sessions.SessionManager = null;
        var yap_session_id: ?i64 = null;

        defer {
            if (yap_win) |win| win.destroy();
            if (yap_sb) |sb| {
                sb.deinit();
                allocator.destroy(sb);
            }
            if (yap_session_manager) |sm| {
                sm.deinit();
                allocator.destroy(sm);
            }
        }

        // Event loop - handle recording/transcription based on state changes
        while (!daemon_should_quit) {
            const current_state = daemon_state.getState();

            // Handle state: recording -> start recording
            if (current_state == .recording and last_state != .recording) {
                std.debug.print("🔴 STATE CHANGED TO RECORDING - Starting audio capture NOW\n", .{});

                if (daemon_status_win) |win| {
                    win.setState("recording");
                    win.addLog(.info, "Recording started");
                    win.setActivity("Recording audio...");
                }

                const start_ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const start_ms = @as(i64, start_ts.sec) * 1000 + @divTrunc(start_ts.nsec, std.time.ns_per_ms);

                recorder.startRecording(recording_file, device) catch |err| {
                    std.debug.print("Error starting recording: {}\n", .{err});

                    if (daemon_status_win) |win| {
                        var err_buf: [256]u8 = undefined;
                        const err_msg = std.fmt.bufPrint(&err_buf, "Recording error: {}", .{err}) catch "Recording error";
                        win.addLog(.err, err_msg);
                        win.setState("idle");
                        win.setActivity("Error");
                    }

                    daemon_state.broadcastError("Failed to start recording", "RECORDING_ERROR") catch {};
                    daemon_state.setState(.idle) catch {};
                    last_state = current_state;
                    continue;
                };

                const end_ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const end_ms = @as(i64, end_ts.sec) * 1000 + @divTrunc(end_ts.nsec, std.time.ns_per_ms);
                std.debug.print("✅ RECORDING ACTIVE - took {d}ms to initialize PulseAudio\n", .{end_ms - start_ms});

                // Play activation sound (2x speed for faster feedback)
                const sound_ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const sound_ms = @as(i64, sound_ts.sec) * 1000 + @divTrunc(sound_ts.nsec, std.time.ns_per_ms);
                utils.playSound("assets/start-fast.wav");
                std.debug.print("🔊 Sound triggered at +{d}ms from state change\n", .{sound_ms - start_ms});

                std.debug.print("🎤 Recording started...\n", .{});
            }

            // Handle state: recording -> record audio chunks
            if (current_state == .recording) {
                _ = recorder.recordChunk() catch |err| {
                    std.debug.print("Error recording chunk: {}\n", .{err});
                    recorder.stopRecording() catch {};
                    daemon_state.broadcastError("Recording failed", "RECORDING_ERROR") catch {};
                    daemon_state.setState(.idle) catch {};
                };
            }

            // Handle state: processing -> stop recording and transcribe
            if (current_state == .processing and last_state == .recording) {
                const stop_start = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const stop_start_ms = @as(i64, stop_start.sec) * 1000 + @divTrunc(stop_start.nsec, std.time.ns_per_ms);

                std.debug.print("🔴 STOP COMMAND RECEIVED - Recording 350ms more to capture trailing words\n", .{});

                // Keep recording for 350ms more to catch trailing speech
                const extra_ms: i64 = 350;
                const deadline = stop_start_ms + extra_ms;
                while (true) {
                    const now = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                    const now_ms = @as(i64, now.sec) * 1000 + @divTrunc(now.nsec, std.time.ns_per_ms);
                    if (now_ms >= deadline) break;

                    // Continue recording chunks
                    _ = recorder.recordChunk() catch break;
                }

                std.debug.print("✅ Extra buffer captured - now stopping\n", .{});
                recorder.stopRecording() catch |err| {
                    std.debug.print("Error stopping recording: {}\n", .{err});
                    daemon_state.broadcastError("Failed to stop recording", "RECORDING_ERROR") catch {};
                    daemon_state.setState(.idle) catch {};
                    last_state = current_state;
                    continue;
                };

                const stop_end = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const stop_end_ms = @as(i64, stop_end.sec) * 1000 + @divTrunc(stop_end.nsec, std.time.ns_per_ms);
                std.debug.print("✅ STOPPED - took {d}ms to finalize recording\n", .{stop_end_ms - stop_start_ms});

                // Play deactivation sound
                utils.playSound("assets/stop.wav");

                std.debug.print("⚙️  Processing transcription...\n", .{});

                if (daemon_status_win) |win| {
                    win.setState("processing");
                    win.addLog(.info, "Transcribing audio...");
                    win.setActivity("Running Whisper model...");
                }

                const start_ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const start_time = @as(i64, start_ts.sec) * 1000 + @divTrunc(start_ts.nsec, std.time.ns_per_ms);

                // Apply VAD to trim silence (if enabled in config)
                var audio_file_to_transcribe: []const u8 = recording_file;
                const vad_trimmed_file = "/tmp/talkies-recording-vad.wav";
                if (cfg.vad_enabled) {
                    const vad_mode: vad.VadMode = switch (cfg.vad_mode) {
                        0 => .quality,
                        1 => .low_bitrate,
                        3 => .very_aggressive,
                        else => .aggressive,
                    };

                    if (daemon_status_win) |win| {
                        win.addLog(.info, "Applying VAD to trim silence...");
                    }

                    const has_voice = audio_processing.trimSilenceFromWav(
                        allocator,
                        recording_file,
                        vad_trimmed_file,
                        vad_mode,
                    ) catch |err| blk: {
                        utils.log("VAD processing failed: {}, continuing without VAD", .{err});
                        break :blk false;
                    };

                    if (has_voice) {
                        audio_file_to_transcribe = vad_trimmed_file;
                        if (daemon_status_win) |win| {
                            win.addLog(.info, "VAD complete - silence trimmed");
                        }
                    } else {
                        utils.log("VAD: No voice detected, skipping transcription", .{});
                        if (daemon_status_win) |win| {
                            win.addLog(.warn, "No voice detected in recording");
                            win.setState("idle");
                        }
                        daemon_state.setState(.idle) catch {};
                        continue;
                    }
                }

                // Transcribe the recording (possibly VAD-trimmed)
                const transcription = whisper_service.transcribe(audio_file_to_transcribe) catch |err| {
                    std.debug.print("Error transcribing: {}\n", .{err});

                    if (daemon_status_win) |win| {
                        var err_buf: [256]u8 = undefined;
                        const err_msg = std.fmt.bufPrint(&err_buf, "Transcription error: {}", .{err}) catch "Transcription error";
                        win.addLog(.err, err_msg);
                        win.setState("idle");
                        win.setActivity("Error");
                    }

                    daemon_state.broadcastError("Transcription failed", "TRANSCRIPTION_ERROR") catch {};
                    daemon_state.setState(.idle) catch {};
                    continue;
                };
                defer allocator.free(transcription);

                const end_ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
                const end_time = @as(i64, end_ts.sec) * 1000 + @divTrunc(end_ts.nsec, std.time.ns_per_ms);
                const duration_ms = end_time - start_time;

                std.debug.print("📝 Transcription ({d} chars): {s}\n", .{ transcription.len, transcription });

                if (daemon_status_win) |win| {
                    var success_buf: [256]u8 = undefined;
                    const success_msg = try std.fmt.bufPrint(&success_buf, "Transcribed: {d} chars in {d}ms", .{ transcription.len, duration_ms });
                    win.addLog(.info, success_msg);
                    win.setLastTranscription("Just now");
                }

                // Broadcast transcription result
                try daemon_state.broadcastTranscription(transcription, duration_ms);

                // Check if we're already in YAP mode - if so, append to existing sandbox
                if (yap_sb) |sb| {
                    std.debug.print("📎 YAP MODE: Appending {d} chars to existing sandbox\n", .{transcription.len});

                    // Append to sandbox yapping with space separator
                    const old_yapping = sb.yapping;
                    const new_yapping = try std.fmt.allocPrint(
                        allocator,
                        "{s} {s}",
                        .{ old_yapping, transcription },
                    );
                    allocator.free(old_yapping);
                    sb.yapping = new_yapping;

                    // Update window display
                    if (yap_win) |win| {
                        win.updateDisplay() catch {};
                    }

                    std.debug.print("📎 Sandbox now has {d} chars total\n", .{new_yapping.len});

                    // Return to yap_refining state and continue
                    try daemon_state.setState(.yap_refining);
                    continue;
                }

                // YAP mode: Interactive refinement with session persistence
                var final_text: []const u8 = transcription;

                yap_block: {
                    if (!cfg.yap_mode_enabled or transcription.len == 0) break :yap_block;

                    utils.log("YAP MODE: Starting interactive refinement session", .{});
                    std.debug.print("\n💬 YAP MODE: Refining your message with {s}...\n", .{cfg.yap_llm_model});

                    // Step 1: Initialize SessionManager
                    const sm_ptr = try allocator.create(yap_sessions.SessionManager);
                    sm_ptr.* = yap_sessions.SessionManager.init(allocator) catch |err| {
                        allocator.destroy(sm_ptr);
                        utils.logError("Failed to initialize session manager: {}", .{err});
                        std.debug.print("⚠️  YAP session manager failed: {}, using basic refinement\n", .{err});
                        break :yap_block;
                    };
                    yap_session_manager = sm_ptr;

                    // Step 2: Create a new session in database
                    yap_session_id = yap_session_manager.?.createSession(
                        transcription,
                        null, // No initial context for now
                        cfg.yap_llm_model,
                        cfg.yap_ollama_url,
                    ) catch |err| {
                        utils.logError("Failed to create YAP session: {}", .{err});
                        std.debug.print("⚠️  YAP session creation failed: {}, using basic refinement\n", .{err});
                        break :yap_block;
                    };

                    utils.log("Created YAP session ID: {d}", .{yap_session_id.?});

                    // Step 3: Create YAP Sandbox with the transcription
                    const sb_ptr = try allocator.create(yap_sandbox.Sandbox);
                    sb_ptr.* = yap_sandbox.Sandbox.init(
                        allocator,
                        transcription,
                        null, // No initial context
                        cfg.yap_ollama_url,
                        cfg.yap_system_prompt,
                        io,
                    ) catch |err| {
                        allocator.destroy(sb_ptr);
                        utils.logError("Failed to create sandbox: {}", .{err});
                        std.debug.print("⚠️  YAP sandbox creation failed: {}, using basic refinement\n", .{err});
                        // Mark session as abandoned
                        if (yap_session_id) |sid| {
                            yap_session_manager.?.abandonSession(sid) catch {};
                        }
                        break :yap_block;
                    };
                    yap_sb = sb_ptr;

                    utils.log("Created YAP sandbox, requesting initial refinement...", .{});

                    // Step 4: Call sandbox.refineInitial() to get first refinement
                    const refined = yap_sb.?.refineInitial(cfg.yap_llm_model) catch |err| {
                        utils.logError("Failed to refine with LLM: {}", .{err});
                        std.debug.print("⚠️  YAP refinement failed: {}, using original transcription\n", .{err});
                        // Mark session as abandoned
                        if (yap_session_id) |sid| {
                            yap_session_manager.?.abandonSession(sid) catch {};
                        }
                        break :yap_block;
                    };

                    std.debug.print("✨ Refined ({d} chars): {s}\n\n", .{ refined.len, refined });

                    // Step 5: Save sandbox to database (all revisions)
                    yap_session_manager.?.saveSandbox(yap_session_id.?, yap_sb.?) catch |err| {
                        utils.logError("Failed to save sandbox to database: {}", .{err});
                        std.debug.print("⚠️  YAP session save failed: {}, but continuing...\n", .{err});
                    };

                    utils.log("YAP session saved to database: {d} revision(s)", .{yap_sb.?.getRevisionCount()});

                    // Step 6: Create and show YAP window for interactive refinement
                    try daemon_state.setState(.yap_refining);

                    yap_win = yap_window.YapWindow.create(
                        allocator,
                        yap_sb.?,
                        &daemon_state,
                    ) catch |err| {
                        utils.logError("Failed to create YAP window: {}", .{err});
                        std.debug.print("⚠️  YAP window creation failed: {}, auto-accepting\n", .{err});
                        final_text = refined;
                        if (yap_session_id) |sid| {
                            yap_session_manager.?.completeSession(sid, final_text) catch {};
                        }
                        break :yap_block;
                    };

                    yap_win.?.show();

                    std.debug.print("💬 YAP window displayed. Use main loop to handle commands...\n", .{});

                    // Don't block - let main loop handle YAP commands
                    // Window will be cleaned up when accept/cancel is pressed
                }

                // Handle output based on config
                if (cfg.auto_paste) {
                    if (final_text.len > 0) {
                        std.debug.print("✨ Inserting text at cursor...\n", .{});
                        inserter.insertTextAtCursor(final_text, cfg.paste_keybind) catch |err| {
                            std.debug.print("Error inserting text: {}\n", .{err});
                        };
                    } else {
                        std.debug.print("⚠️  Skipping paste - text is empty\n", .{});
                    }
                } else {
                    var clip = clipboard.Clipboard.init(allocator);
                    defer clip.deinit();

                    std.debug.print("📋 Copying to clipboard...\n", .{});
                    clip.copy(final_text) catch |err| {
                        std.debug.print("Error copying to clipboard: {}\n", .{err});
                    };
                }

                std.debug.print("✅ Done!\n\n", .{});

                // Cleanup recording file
                std.fs.deleteFileAbsolute(recording_file) catch {};

                // Reset state to idle
                try daemon_state.setState(.idle);

                if (daemon_status_win) |win| {
                    win.setState("idle");
                    win.addLog(.info, "Ready for next recording");
                    win.setActivity("Idle");
                }
            }

            // Process YAP window events if active
            if (yap_win) |win| {
                yap_window.YapWindow.processEvents();

                // Check for YAP commands
                if (daemon_state.getYapCommand()) |cmd| {
                    daemon_state.clearYapCommand();

                    switch (cmd) {
                        .accept => {
                            const final_text = yap_sb.?.getCurrentRefinement();
                            if (yap_session_id) |sid| {
                                yap_session_manager.?.completeSession(sid, final_text) catch {};
                            }
                            std.debug.print("✅ YAP: Accepted refinement\n", .{});

                            // Cleanup YAP session
                            win.destroy();
                            yap_win = null;
                            if (yap_sb) |sb| {
                                sb.deinit();
                                allocator.destroy(sb);
                                yap_sb = null;
                            }
                            if (yap_session_manager) |sm| {
                                sm.deinit();
                                allocator.destroy(sm);
                                yap_session_manager = null;
                            }
                            yap_session_id = null;

                            // Paste or copy the result
                            if (cfg.auto_paste) {
                                if (final_text.len > 0) {
                                    std.debug.print("✨ Inserting text at cursor...\n", .{});
                                    inserter.insertTextAtCursor(final_text, cfg.paste_keybind) catch |err| {
                                        std.debug.print("Error inserting text: {}\n", .{err});
                                    };
                                }
                            } else {
                                var clip = clipboard.Clipboard.init(allocator);
                                defer clip.deinit();
                                clip.copy(final_text) catch |err| {
                                    std.debug.print("Error copying to clipboard: {}\n", .{err});
                                };
                            }

                            try daemon_state.setState(.idle);
                        },

                        .request_clarification => {
                            std.debug.print("🤔 YAP: Generating clarification questions...\n", .{});

                            // Generate questions using LLM
                            const questions = yap_sb.?.generateClarificationQuestions(
                                cfg.yap_llm_model,
                            ) catch |err| {
                                utils.logError("Clarification generation failed: {}", .{err});
                                std.debug.print("⚠️  Clarification failed, falling back to direct refinement: {}\n", .{err});
                                // Fallback: skip clarification and refine directly
                                daemon_state.setYapCommand(.refine, null) catch {};
                                continue;
                            };

                            std.debug.print("✅ Generated {d} questions\n", .{questions.len});

                            // Store questions in daemon state
                            daemon_state.setClarificationQuestions(questions) catch {};

                            // Convert to C-compatible format for GTK
                            const c_questions = allocator.alloc(yap_window.c.YapClarificationQuestion, questions.len) catch continue;
                            defer allocator.free(c_questions);

                            // Convert options to NULL-terminated arrays
                            var options_arrays = allocator.alloc([*c]const [*c]const u8, questions.len) catch continue;
                            defer allocator.free(options_arrays);

                            for (questions, 0..) |q, i| {
                                const opts = allocator.alloc([*c]const u8, q.options.len) catch continue;
                                for (q.options, 0..) |opt, j| {
                                    opts[j] = opt.ptr;
                                }
                                options_arrays[i] = opts.ptr;

                                c_questions[i] = .{
                                    .id = q.id.ptr,
                                    .question_text = q.text.ptr,
                                    .options = opts.ptr,
                                    .option_count = @intCast(q.options.len),
                                };
                            }

                            // Show in UI
                            yap_window.c.yap_window_gtk_show_clarification(
                                win.gtk_win,
                                c_questions.ptr,
                                @intCast(questions.len),
                            );

                            win.clarification_active = true;

                            // Clean up options arrays
                            for (options_arrays) |opts| {
                                allocator.free(opts[0 .. questions[0].options.len]);
                            }
                        },

                        .refine => {
                            const ctx = daemon_state.getYapRefineContext();
                            defer if (ctx) |c| allocator.free(c);

                            // Check if this is first refinement
                            const is_first = yap_sb.?.getRevisionCount() == 0;

                            if (is_first) {
                                // First refinement with clarification answers
                                std.debug.print("🔄 YAP: Performing initial refinement with clarification...\n", .{});

                                const clarification_answers = daemon_state.getClarificationAnswers() catch &[_]daemon_ws.ClarificationAnswer{};
                                defer {
                                    for (clarification_answers) |*item| {
                                        var mutable_item = item.*;
                                        mutable_item.deinit(allocator);
                                    }
                                    allocator.free(clarification_answers);
                                }

                                const new_refined = yap_sb.?.refineInitialWithClarification(
                                    cfg.yap_llm_model,
                                    if (clarification_answers.len > 0) clarification_answers else null,
                                ) catch |err| {
                                    utils.logError("Initial refinement failed: {}", .{err});
                                    std.debug.print("⚠️  Initial refinement failed: {}\n", .{err});
                                    continue;
                                };

                                std.debug.print("✨ Initial refinement complete: {s}\n", .{new_refined});

                                // Clear clarification state after first refinement
                                daemon_state.clearClarificationState();

                                // Save updated sandbox
                                yap_session_manager.?.saveSandbox(yap_session_id.?, yap_sb.?) catch {};

                                // Update window display
                                win.updateDisplay() catch {};

                                // Broadcast new refinement
                                daemon_state.broadcastYapRefined(
                                    new_refined,
                                    @intCast(yap_sb.?.getRevisionCount()),
                                    yap_sb.?.yapping.len,
                                ) catch {};
                            } else {
                                // Subsequent refinement
                                std.debug.print("🔄 YAP: Requesting another refinement (context and yapping updated)...\n", .{});

                                const new_refined = yap_sb.?.refineAgain(
                                    cfg.yap_llm_model,
                                    ctx,
                                ) catch |err| {
                                    utils.logError("Refinement failed: {}", .{err});
                                    std.debug.print("⚠️  Refinement failed: {}\n", .{err});
                                    continue;
                                };

                                std.debug.print("✨ New refinement: {s}\n", .{new_refined});

                                // Save updated sandbox
                                yap_session_manager.?.saveSandbox(yap_session_id.?, yap_sb.?) catch {};

                                // Update window display
                                win.updateDisplay() catch {};

                                // Broadcast new refinement
                                daemon_state.broadcastYapRefined(
                                    new_refined,
                                    @intCast(yap_sb.?.getRevisionCount()),
                                    yap_sb.?.yapping.len,
                                ) catch {};
                            }
                        },

                        .cancel => {
                            const final_text = yap_sb.?.yapping;
                            if (yap_session_id) |sid| {
                                yap_session_manager.?.abandonSession(sid) catch {};
                            }
                            std.debug.print("❌ YAP: Cancelled, using original\n", .{});

                            // Cleanup
                            win.destroy();
                            yap_win = null;
                            if (yap_sb) |sb| {
                                sb.deinit();
                                allocator.destroy(sb);
                                yap_sb = null;
                            }
                            if (yap_session_manager) |sm| {
                                sm.deinit();
                                allocator.destroy(sm);
                                yap_session_manager = null;
                            }
                            yap_session_id = null;

                            // Paste or copy the original
                            if (cfg.auto_paste) {
                                if (final_text.len > 0) {
                                    inserter.insertTextAtCursor(final_text, cfg.paste_keybind) catch {};
                                }
                            } else {
                                var clip = clipboard.Clipboard.init(allocator);
                                defer clip.deinit();
                                clip.copy(final_text) catch {};
                            }

                            try daemon_state.setState(.idle);
                        },

                        .append_transcription => {
                            // Handled earlier in transcription processing
                        },
                    }
                }
            }

            // Process GTK events to keep status window responsive
            if (daemon_status_win) |_| {
                daemon_status_window.DaemonStatusWindow.processEvents();
            }

            // Update last state
            last_state = current_state;

            // Sleep to avoid busy-wait (0.5ms for ultra-fast response)
            std.posix.nanosleep(0, 500 * std.time.ns_per_us);
        }

        utils.log("Daemon shutting down...", .{});
        return;
    }

    // X11 mode: Setup hotkey listener and audio recorder
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    var listener = hotkey.HotkeyListener.init(allocator);
    defer listener.deinit();

    try listener.start();

    // State tracking
    var is_recording = false;
    var key_press_time: std.time.Instant = undefined;
    const temp_path = "/tmp/talkies_daemon_recording.wav";

    // Main event loop
    while (!daemon_should_quit) {
        // TODO: Process tray events when tray is re-enabled
        // try system_tray.processEvents();

        // TODO: Show settings UI when GTK bindings support Zig 0.16
        // if (daemon_show_settings) {
        //     daemon_show_settings = false;
        //     try ui.show();
        // }

        const event = try listener.poll();

        if (event) |evt| {
            switch (evt) {
                .press => {
                    if (!is_recording) {
                        // Start recording
                        is_recording = true;
                        key_press_time = try std.time.Instant.now();

                        const device = if (cfg.audio_device.len > 0) cfg.audio_device else null;
                        recorder.startRecording(temp_path, device) catch |err| {
                            std.debug.print("Error starting recording: {}\n", .{err});
                            is_recording = false;
                            continue;
                        };

                        std.debug.print("🔴 Recording started...\n", .{});

                        // Start recording loop in background
                        // We need to poll for audio chunks while also checking for key release
                        while (is_recording) {
                            // Record a chunk (100ms of audio)
                            _ = recorder.recordChunk() catch |err| {
                                std.debug.print("Error recording chunk: {}\n", .{err});
                                is_recording = false;
                                break;
                            };

                            // Small sleep to match chunk rate (100ms chunks at 16kHz = 4096 bytes)
                            std.posix.nanosleep(0, 100 * std.time.ns_per_ms);

                            // Check if there's a pending key release event
                            if (listener.hasPendingEvents()) {
                                break; // Exit recording loop to process event
                            }
                        }
                    }
                },
                .release => {
                    if (is_recording) {
                        // Calculate hold duration
                        const now = try std.time.Instant.now();
                        const hold_duration_ns = now.since(key_press_time);
                        const hold_duration = hold_duration_ns / std.time.ns_per_ms;

                        // Stop recording
                        recorder.stopRecording() catch |err| {
                            std.debug.print("Error stopping recording: {}\n", .{err});
                            is_recording = false;
                            continue;
                        };

                        is_recording = false;

                        // Check if it was a tap (< 300ms) or hold
                        if (hold_duration < 300) {
                            std.debug.print("⏹️  Recording stopped (tap detected - quick mode)\n", .{});
                        } else {
                            std.debug.print("⏹️  Recording stopped ({d}ms hold)\n", .{hold_duration});
                        }

                        // Transcribe
                        std.debug.print("⚙️  Transcribing...\n", .{});
                        const transcription = whisper_service.transcribe(temp_path) catch |err| {
                            std.debug.print("Error transcribing: {}\n", .{err});
                            continue;
                        };
                        defer allocator.free(transcription);

                        std.debug.print("📝 Transcription: {s}\n", .{transcription});

                        // Handle output based on config
                        if (cfg.auto_paste) {
                            std.debug.print("✨ Inserting text at cursor...\n", .{});
                            inserter.insertTextAtCursor(transcription, cfg.paste_keybind) catch |err| {
                                std.debug.print("Error inserting text: {}\n", .{err});
                            };
                        } else {
                            var clip = clipboard.Clipboard.init(allocator);
                            defer clip.deinit();

                            std.debug.print("📋 Copying to clipboard...\n", .{});
                            clip.copy(transcription) catch |err| {
                                std.debug.print("Error copying to clipboard: {}\n", .{err});
                            };
                        }

                        std.debug.print("✅ Done!\n\n", .{});

                        // Cleanup temp file
                        std.fs.deleteFileAbsolute(temp_path) catch {};
                    }
                },
            }
        }
    }
}

fn printHelp() !void {
    const help_text =
        \\Talkies - Voice transcription and text insertion
        \\
        \\Usage:
        \\  talkies <command> [args]
        \\
        \\Commands:
        \\  daemon             Run as background daemon (Right Alt to record)
        \\  quick              Record, transcribe, and paste in one step
        \\  record             Record audio only
        \\  models             Download whisper models
        \\  config             Show current configuration
        \\  audio              Test audio recording (5 seconds)
        \\  audio-list         List available input devices
        \\  audio-set <device> Set audio input device
        \\  transcribe         Test transcription on anime_16k.wav
        \\  help               Show this help message
        \\
        \\Examples:
        \\  talkies daemon                      # Start daemon, press Right Alt to record
        \\  talkies audio-list                  # Show all input devices
        \\  talkies audio-set alsa_input.usb... # Set input device
        \\  talkies quick                       # One-shot recording workflow
        \\  talkies models                      # Download model from config
        \\
    ;

    std.debug.print("{s}\n", .{help_text});
}

test "command parsing" {
    try std.testing.expectEqual(Command.quick, parseCommand("quick").?);
    try std.testing.expectEqual(Command.help, parseCommand("--help").?);
    try std.testing.expect(parseCommand("invalid") == null);
}
