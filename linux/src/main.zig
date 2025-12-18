const std = @import("std");
const audio = @import("audio.zig");
const whisper = @import("whisper.zig");
const clipboard = @import("clipboard.zig");
const input = @import("input.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");
const hotkey = @import("hotkey.zig");
// TODO: Re-enable after fixing GTK4 cImport issues
// const tray = @import("tray.zig");
// const settings_ui = @import("settings_ui.zig");

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
        try inserter.insertTextAtCursor(transcription);
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

    // TODO: Re-enable system tray and settings UI after fixing GTK4 cImport issues
    // Initialize system tray
    // var system_tray = tray.SystemTray.init(allocator);
    // defer system_tray.deinit();

    // system_tray.setQuitCallback(&onQuitCallback);
    // system_tray.setSettingsCallback(&onSettingsCallback);

    // try system_tray.start();
    // utils.log("System tray initialized", .{});

    // Initialize settings UI (but don't show yet)
    // var ui = settings_ui.SettingsUI.init(allocator, &cfg);
    // defer ui.deinit();

    // Get effective platform (resolve "auto")
    const platform = cfg.getEffectivePlatform();
    const is_wayland = std.mem.eql(u8, platform, "wayland");

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
    var recorder = audio.AudioRecorder.init(allocator);
    defer recorder.deinit();

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();

    var inserter = input.TextInserter.init(allocator);
    defer inserter.deinit();

    // Load whisper model once at startup
    std.debug.print("Loading whisper model '{s}'...\n", .{cfg.model});
    try whisper_service.loadModel(cfg.model);
    std.debug.print("Model loaded. Ready!\n\n", .{});

    // In Wayland mode, just keep model loaded and wait for toggle script
    if (is_wayland) {
        std.debug.print("Wayland mode: Daemon will keep model loaded for quick transcription\n", .{});
        std.debug.print("Use the toggle script (Super+Alt+T) to trigger recordings\n\n", .{});

        // Event loop for tray and settings UI (disabled for now)
        while (!daemon_should_quit) {
            // TODO: Process tray events when tray is re-enabled
            // try system_tray.processEvents();

            // Check if settings should be shown
            // if (daemon_show_settings) {
            //     daemon_show_settings = false;
            //     try ui.show();
            // }

            // Small sleep to avoid busy-wait
            std.posix.nanosleep(0, 50 * std.time.ns_per_ms);
        }

        utils.log("Daemon shutting down...", .{});
        return;
    }

    // X11 mode: Setup hotkey listener
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

        // Check if settings should be shown
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
                            inserter.insertTextAtCursor(transcription) catch |err| {
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
