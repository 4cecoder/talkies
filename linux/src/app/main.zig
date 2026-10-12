//! Layer 4 - app (highest volatility): CLI entry point. Product behaviour
//! (daemon pipeline, config schema, prompts, hotkey policy, YAP) lives in
//! this layer; it composes the `core` and `engine` modules and the C UI
//! shared library (libtalkies-ui).

const std = @import("std");

const core = @import("core");
const utils = core.utils;
const transcript_export = core.transcript_export;
const local_diagnostics = core.local_diagnostics;

const engine = @import("engine");
const audio = engine.audio;
const whisper = engine.whisper;
const cleanup = engine.cleanup;
const clipboard = engine.clipboard;
const input = engine.input;

const config = @import("config.zig");
const daemon = @import("daemon.zig");
const offline_acceptance = @import("offline_acceptance.zig");

test {
    _ = config;
    _ = daemon;
    _ = offline_acceptance;
    _ = @import("enhance.zig");
    _ = @import("trigger.zig");
    _ = @import("daemon_ws.zig");
    _ = @import("daemon_status_window.zig");
    _ = @import("ollama.zig");
}

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

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.smp_allocator;
    utils.setIoAllocator(allocator);

    run(init, allocator) catch |err| {
        local_diagnostics.recordUnhandledError(allocator, @errorName(err), @errorReturnTrace());
        return err;
    };
}

fn run(init: std.process.Init.Minimal, allocator: std.mem.Allocator) !void {
    var args_iterator = try std.process.Args.Iterator.initAllocator(init.args, allocator);
    defer args_iterator.deinit();

    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(allocator);
    while (args_iterator.next()) |arg| try args.append(allocator, arg);
    const arguments = args.items;

    if (arguments.len < 2) {
        try printHelp();
        return;
    }

    const command = parseCommand(arguments[1]) orelse {
        std.debug.print("Unknown command: {s}\n", .{arguments[1]});
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
        .audio_set => try runAudioSet(allocator, arguments),
        .transcribe_test => try runTranscribeTest(allocator, arguments),
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
    whisper_service.configure(cfg.language, cfg.threads);

    var cleanup_service = cleanup.Cleaner{ .allocator = allocator, .threads = cfg.threads };
    defer cleanup_service.deinit();

    var clip = clipboard.Clipboard.init(allocator);
    defer clip.deinit();

    var inserter = input.TextInserter.init(allocator);
    defer inserter.deinit();

    // Create temp file for recording
    const temp_path = try utils.privateRuntimePath(allocator, "quick-recording.wav");
    defer allocator.free(temp_path);

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

        utils.sleepNanoseconds(chunk_ms * std.time.ns_per_ms);
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
    const raw_transcription = try whisper_service.transcribe(temp_path, cfg.vocabulary_prompt);
    defer allocator.free(raw_transcription);
    const cleaned_transcription = if (cfg.s1CleanupEnabled())
        cleanup_service.clean(raw_transcription, .{}) catch |err| blk: {
            utils.logError("S1-mini cleanup failed; keeping raw transcript: {}", .{err});
            break :blk null;
        }
    else
        null;
    defer if (cleaned_transcription) |cleaned| allocator.free(cleaned);
    const transcription = cleaned_transcription orelse raw_transcription;

    std.debug.print("\nTranscription:\n{s}\n\n", .{transcription});

    // Handle output based on config
    if (cfg.auto_paste) {
        std.debug.print("Inserting text at cursor...\n", .{});
        try inserter.insertTextAtCursor(transcription, cfg.paste_keybind, cfg.restore_clipboard);
        std.debug.print("Text inserted successfully!\n", .{});
    } else {
        std.debug.print("Copying to clipboard...\n", .{});
        try clip.copy(transcription);
        std.debug.print("Text copied to clipboard!\n", .{});
    }

    // Cleanup temp file
    std.Io.Dir.deleteFileAbsolute(utils.io(), temp_path) catch |err| {
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

        utils.sleepNanoseconds(chunk_ms * std.time.ns_per_ms);
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
    whisper_service.configure(cfg.language, cfg.threads);

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

        utils.sleepNanoseconds(chunk_ms * std.time.ns_per_ms);
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
    var child = try std.process.spawn(utils.io(), .{ .argv = argv, .stdout = .pipe, .stderr = .pipe });

    const stdout = child.stdout orelse return error.NoStdout;

    // Read output
    var output_list = std.ArrayList(u8).empty;
    defer output_list.deinit(allocator);

    var buffer: [4096]u8 = undefined;
    while (true) {
        const n = stdout.readStreaming(utils.io(), &.{&buffer}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (n == 0) break;
        try output_list.appendSlice(allocator, buffer[0..n]);
    }

    const term = try child.wait(utils.io());
    if (!term.success()) {
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

fn runAudioSet(allocator: std.mem.Allocator, args: []const []const u8) !void {
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
    try cfg.setString("audio_device", device_name);

    // Save config
    try cfg.save();

    std.debug.print("✅ Audio device updated successfully!\n", .{});
    std.debug.print("Device: {s}\n", .{device_name});
    std.debug.print("\nYou can test it with: talkies audio\n", .{});
}

fn runTranscribeTest(allocator: std.mem.Allocator, args: []const []const u8) !void {
    // Get audio file from args or use default
    if (args.len < 3) {
        std.debug.print("Usage: talkies transcribe <file.wav> [--format txt|vtt|srt --output <file>]\n", .{});
        return error.MissingArgument;
    }
    const audio_file = args[2];

    utils.log("Testing transcription with {s}...", .{audio_file});

    // Load config to get model name
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    std.debug.print("Loading whisper model '{s}'...\n", .{cfg.model});

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();
    whisper_service.configure(cfg.language, cfg.threads);

    try whisper_service.loadModel(cfg.model);

    std.debug.print("Transcribing {s}...\n", .{audio_file});
    const transcription = try whisper_service.transcribe(audio_file, cfg.vocabulary_prompt);
    defer allocator.free(transcription);

    const export_args = if (args.len > 3) args[3..] else &.{};
    if (try transcript_export.parseRequest(export_args)) |request| {
        const source_segments = try whisper_service.getSegments();
        defer if (source_segments.len > 0) whisper_service.freeSegments(source_segments);
        const export_segments = try allocator.alloc(transcript_export.Segment, source_segments.len);
        defer allocator.free(export_segments);
        for (source_segments, export_segments) |source, *target| {
            target.* = .{ .start = source.start, .end = source.end, .text = source.text };
        }

        const content = try transcript_export.render(allocator, request.format, export_segments);
        defer allocator.free(content);
        const file = try std.Io.Dir.cwd().createFile(utils.io(), request.output_path, .{
            .exclusive = true,
            .permissions = @fromBackingInt(@as(u32, 0o600)),
        });
        defer file.close(utils.io());
        errdefer std.Io.Dir.cwd().deleteFile(utils.io(), request.output_path) catch {};
        try file.writeStreamingAll(utils.io(), content);
        std.debug.print("Exported local ASR transcript to: {s}\n", .{request.output_path});
    } else {
        std.debug.print("\n=== TRANSCRIPTION ===\n{s}\n=====================\n", .{transcription});
    }
}

fn runDaemon(allocator: std.mem.Allocator) !void {
    try daemon.run(allocator);
}

fn printHelp() !void {
    const help_text =
        \\Talkies - Voice transcription and text insertion
        \\
        \\Usage:
        \\  talkies <command> [args]
        \\
        \\Commands:
        \\  daemon             Run the dictation daemon (HUD, tray, Right Alt / compositor hotkey)
        \\  quick              Record, transcribe, and paste in one step
        \\  record             Record audio only
        \\  models             Download whisper models
        \\  config             Show current configuration
        \\  audio              Test audio recording (5 seconds)
        \\  audio-list         List available input devices
        \\  audio-set <device> Set audio input device
        \\  transcribe [wav]   Transcribe a WAV, optionally exporting TXT/VTT/SRT
        \\  help               Show this help message
        \\
        \\Examples:
        \\  talkies daemon                      # Start daemon, press Right Alt to record
        \\  talkies audio-list                  # Show all input devices
        \\  talkies audio-set alsa_input.usb... # Set input device
        \\  talkies quick                       # One-shot recording workflow
        \\  talkies models                      # Download model from config
        \\  talkies transcribe speech.wav --format srt --output speech.srt
        \\
    ;

    std.debug.print("{s}\n", .{help_text});
}

test "command parsing" {
    try std.testing.expectEqual(Command.quick, parseCommand("quick").?);
    try std.testing.expectEqual(Command.help, parseCommand("--help").?);
    try std.testing.expect(parseCommand("invalid") == null);
}
