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
const speech = engine.speech;
const speech_policy = engine.speech_policy;
const phonon = engine.phonon;
const phonon_model = engine.phonon_model;
const cleanup = engine.cleanup;
const clipboard = engine.clipboard;
const input = engine.input;

const config = @import("config.zig");
const daemon = @import("daemon.zig");
const offline_acceptance = @import("offline_acceptance.zig");
const health = @import("health.zig");
const history = @import("history.zig");
const updater = @import("updater.zig");
const evdev_hotkey = engine.evdev_hotkey;
const c_tray = @import("c_tray");
const build_options = @import("build_options");

test {
    _ = config;
    _ = daemon;
    _ = offline_acceptance;
    _ = @import("enhance.zig");
    _ = @import("trigger.zig");
    _ = @import("state.zig");
    _ = health;
    _ = history;
    _ = updater;
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
    doctor,
    history,
    update,
    version,
    help,
};

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.smp_allocator;
    utils.setIoAllocator(allocator);

    run(init, allocator) catch |err| switch (err) {
        // Expected, already explained to the user: not a crash.
        error.AlreadyRunning, error.MissingArgument, error.InvalidArgument, error.UpdateFailed => std.process.exit(1),
        error.UnknownCommand => std.process.exit(2),
        else => {
            local_diagnostics.recordUnhandledError(allocator, @errorName(err), @errorReturnTrace());
            return err;
        },
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
        return error.UnknownCommand;
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
        .doctor => try runDoctor(allocator),
        .history => try runHistory(allocator, arguments[2..]),
        .update => try runUpdate(allocator, arguments[2..]),
        .version => try utils.writeStdout("talkies " ++ build_options.version ++ "\n"),
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
        .{ "doctor", .doctor },
        .{ "history", .history },
        .{ "update", .update },
        .{ "version", .version },
        .{ "--version", .version },
        .{ "-V", .version },
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

    var recognizer = speech.Recognizer.init(allocator);
    defer recognizer.deinit();
    _ = recognizer.configure(daemon.speechPreference(cfg.speech_engine), cfg.model, cfg.language, cfg.threads);

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

    // Load the speech model (Phonon-2, else Whisper)
    std.debug.print("Loading speech model...\n", .{});
    const backend = try recognizer.prepare();
    std.debug.print("Using {s}\n", .{backend.displayName()});

    // Transcribe
    std.debug.print("Transcribing audio...\n", .{});
    const transcript = try recognizer.transcribe(temp_path, cfg.vocabulary_prompt);
    const raw_transcription = transcript.text;
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

/// Explicit, verified downloads: Phonon-2 (unless Whisper is selected) and
/// the Whisper model named in the config, which is always the fallback.
fn runModelsDownload(allocator: std.mem.Allocator) !void {
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    if (cfg.speech_engine != .whisper) {
        std.debug.print("Downloading Phonon-2 ({d} MB, pinned {s}@{s})...\n", .{ phonon_model.downloadSize() / 1_000_000, phonon_model.repository, phonon_model.revision[0..10] });
        const store: phonon_model.ModelStore = .{ .allocator = allocator };
        try store.download();
        std.debug.print("Phonon-2 verified and installed.\n", .{});
    }

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();
    whisper_service.configure(cfg.language, cfg.threads);

    std.debug.print("Downloading Whisper model: {s}\n", .{cfg.model});
    std.debug.print("This may take a few minutes...\n", .{});

    try whisper_service.downloadModel(cfg.model);

    std.debug.print("Models downloaded successfully!\n", .{});
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

    const export_args = if (args.len > 3) args[3..] else &.{};
    const export_request = try transcript_export.parseRequest(export_args);
    if (export_request == null) {
        // Plain text: the same recognizer chain as dictation.
        var recognizer = speech.Recognizer.init(allocator);
        defer recognizer.deinit();
        _ = recognizer.configure(daemon.speechPreference(cfg.speech_engine), cfg.model, cfg.language, cfg.threads);
        _ = try recognizer.prepare();
        std.debug.print("Transcribing {s}...\n", .{audio_file});
        const transcript = try recognizer.transcribe(audio_file, cfg.vocabulary_prompt);
        defer allocator.free(transcript.text);
        std.debug.print("\n=== TRANSCRIPTION ({s}) ===\n{s}\n=====================\n", .{ transcript.backend.displayName(), transcript.text });
        return;
    }

    // Timed exports need Whisper's segment timestamps.
    std.debug.print("Loading whisper model '{s}' (timed export)...\n", .{cfg.model});

    var whisper_service = whisper.WhisperService.init(allocator);
    defer whisper_service.deinit();
    whisper_service.configure(cfg.language, cfg.threads);

    try whisper_service.loadModel(cfg.model);

    std.debug.print("Transcribing {s}...\n", .{audio_file});
    const transcription = try whisper_service.transcribe(audio_file, cfg.vocabulary_prompt);
    defer allocator.free(transcription);

    if (export_request) |request| {
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
    }
}

/// Print what Talkies detected about this system and how to fix problems.
fn runDoctor(allocator: std.mem.Allocator) !void {
    var cfg = config.Config.init(allocator);
    defer cfg.deinit();
    try cfg.load();

    const wayland = std.mem.eql(u8, cfg.getEffectivePlatform(), "wayland");
    var listener = evdev_hotkey.Listener.open();
    defer listener.deinit();
    const probe: health.Probe = .{
        .hotkey = if (!wayland) .x11_grab else if (listener.count > 0) .evdev else .compositor_only,
        .tray_host = c_tray.talkies_tray_host_available() != 0,
        .model = cfg.model,
        .model_missing_bytes = whisper.missingModelBytes(allocator, cfg.model) catch |err| blk: {
            std.debug.print("Could not check the Whisper model: {}\n", .{err});
            break :blk 0;
        },
        .speech = doctorSpeechStatus(allocator, &cfg),
    };
    var report = try health.run(allocator, &cfg, probe);
    defer report.deinit();

    std.debug.print("\nTalkies system check\n\n", .{});
    for (report.checks.items) |check| {
        const mark = switch (check.level) {
            .ok => "ok  ",
            .warn => "warn",
            .fail => "FAIL",
        };
        std.debug.print("  [{s}] {s}: {s}\n", .{ mark, check.title, check.detail });
        if (check.level != .ok and check.fix.len > 0) std.debug.print("         -> {s}\n", .{check.fix});
    }
    std.debug.print("\n{s}\n", .{switch (report.worst()) {
        .ok => "Everything looks good.",
        .warn => "Talkies works, with the limitations above.",
        .fail => "Fix the FAIL items above for dictation to work.",
    }});
}

/// What the daemon would use, without loading the 674 MB model.
fn doctorSpeechStatus(allocator: std.mem.Allocator, cfg: *const config.Config) health.SpeechStatus {
    const store: phonon_model.ModelStore = .{ .allocator = allocator };
    const p = speech_policy.plan(daemon.speechPreference(cfg.speech_engine), cfg.language, store.isInstalled());
    const selected = cfg.speech_engine == .phonon;
    if (p.phonon_skipped) |reason| return .{
        .phonon_active = false,
        .reason = reason.describe(),
        .phonon_selected = selected,
        .phonon_missing = reason == .not_installed,
    };
    var dir_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    if (phonon.runtimeDir(&dir_buf) == null) return .{
        .phonon_active = false,
        .reason = "the CrispASR runtime (lib/crispasr) is not installed",
        .phonon_selected = selected,
        .phonon_failed = true,
    };
    return .{ .phonon_active = true, .phonon_selected = selected };
}

const HistoryRequest = union(enum) {
    list: struct { search: ?[]const u8 = null, limit: u32 = history.page_size, json: bool = false },
    clear,
};

fn parseHistoryArgs(args: []const []const u8) !HistoryRequest {
    if (args.len == 1 and std.mem.eql(u8, args[0], "clear")) return .clear;
    var request: HistoryRequest = .{ .list = .{} };
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--json")) {
            request.list.json = true;
        } else if (std.mem.eql(u8, arg, "--search") or std.mem.eql(u8, arg, "--limit")) {
            i += 1;
            if (i == args.len) return error.MissingArgument;
            if (arg[2] == 's') {
                request.list.search = args[i];
            } else {
                request.list.limit = std.fmt.parseInt(u32, args[i], 10) catch return error.InvalidArgument;
                if (request.list.limit == 0) return error.InvalidArgument;
            }
        } else {
            return error.InvalidArgument;
        }
    }
    return request;
}

/// `talkies history [--search Q] [--limit N] [--json]` and `talkies history
/// clear`. Transcripts go to stdout only because the user asked for them.
fn runHistory(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const request = parseHistoryArgs(args) catch |err| {
        std.debug.print("Usage: talkies history [--search TEXT] [--limit N] [--json]\n       talkies history clear\n", .{});
        return err;
    };
    var store = try history.Store.openDefault(allocator);
    defer store.close();

    const options = switch (request) {
        .clear => {
            const removed = try store.count();
            try store.clear();
            std.debug.print("Deleted {d} transcript{s} from history.\n", .{ removed, if (removed == 1) "" else "s" });
            return;
        },
        .list => |options| options,
    };
    var page = try store.list(allocator, .{ .search = options.search, .limit = options.limit });
    defer page.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    defer out.deinit();
    if (options.json) {
        try history.writeJson(&out.writer, page.entries);
    } else {
        for (page.entries) |entry| {
            var time_buf: [32]u8 = undefined;
            try out.writer.print("{s}  {s}\n", .{ localTime(&time_buf, entry.created_at_ms), entry.text });
        }
        if (page.entries.len == 0) std.debug.print("No transcripts{s}.\n", .{if (options.search != null) " match" else " saved yet"});
        if (page.has_more) std.debug.print("(showing the newest {d}; use --limit for more)\n", .{options.limit});
    }
    try utils.writeStdout(out.written());
}

// libc's local-time formatting (Zig's std has no time zone database). The
// struct tm is opaque here: 64 aligned bytes cover glibc's 56-byte layout.
const Tm = extern struct { bytes: [64]u8 align(8) };
extern "c" fn localtime_r(timer: *const i64, result: *Tm) ?*Tm;
extern "c" fn strftime(buf: [*]u8, max: usize, format: [*:0]const u8, tm: *const Tm) usize;

fn localTime(buf: []u8, epoch_ms: i64) []const u8 {
    const seconds = @divFloor(epoch_ms, 1000);
    var tm: Tm = undefined;
    if (localtime_r(&seconds, &tm) == null) return "";
    return buf[0..strftime(buf.ptr, buf.len, "%Y-%m-%d %H:%M", &tm)];
}

fn runDaemon(allocator: std.mem.Allocator) !void {
    // Returns only after the daemon released its windows, devices and port.
    const restart_exe = try daemon.run(allocator) orelse return;
    defer allocator.free(restart_exe);
    try updater.relaunchDaemon(allocator, restart_exe);
}

/// `talkies update [--check]`: compare with GitHub Releases and, after
/// confirmation, install the verified update the way Talkies was installed.
fn runUpdate(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const check_only = args.len == 1 and std.mem.eql(u8, args[0], "--check");
    if (args.len > 0 and !check_only) {
        std.debug.print("Usage: talkies update [--check]\n", .{});
        return error.InvalidArgument;
    }
    const build = updater.currentBuild();
    const exe = try updater.currentExe(allocator);
    defer allocator.free(exe);
    const method = try updater.detectInstall(allocator, .{ .exe = exe });
    std.debug.print("Installed: Talkies {s} ({s}{s}{s}), {s}\n", .{
        build.version,
        if (build.channel.len > 0) build.channel else "no channel",
        if (build.commit.len >= 7) ", commit " else "",
        if (build.commit.len >= 7) build.commit[0..7] else "",
        method.describe(),
    });
    if (updater.trackOf(build) == null) {
        std.debug.print("This build does not follow a release channel (development or CI build), so it cannot update itself.\n", .{});
        return;
    }
    if (updater.disabledByEnv()) {
        std.debug.print("Update checks are turned off ({s} is set).\n", .{updater.disable_env});
        return;
    }

    std.debug.print("Checking {s} ...\n", .{updater.buildInfoUrl(updater.trackOf(build).?)});
    const found = updater.check(allocator, build) catch |err| {
        std.debug.print("Could not check for updates: {s}\n", .{@errorName(err)});
        if (err == error.UpdateCheckFailed) std.debug.print("The check needs curl and HTTPS access to github.com.\n", .{});
        return error.UpdateFailed;
    };
    var available = found orelse {
        std.debug.print("Talkies is up to date.\n", .{});
        return;
    };
    defer available.deinit();
    var label_buf: [64]u8 = undefined;
    const label = available.label(&label_buf);
    std.debug.print("Update available: Talkies {s} (release {s}).\n", .{ label, available.remote.release });
    if (check_only) return;
    if (method.manualInstructions()) |how| {
        std.debug.print("{s}\n", .{how});
        return;
    }

    switch (method) {
        .tarball => |t| if (t.writable)
            std.debug.print("This replaces {s}/lib/talkies.\n", .{t.prefix})
        else
            std.debug.print("{s} belongs to root: the verified tarball's install.sh runs through pkexec.\n", .{t.prefix}),
        .package => |tool| std.debug.print("This runs: {s}\n", .{updater.approvalCommand(tool)}),
        else => {},
    }
    if (!confirm("Download, verify and install it? [y/N] ")) {
        std.debug.print("Not installed.\n", .{});
        return;
    }
    const new_exe = updater.install(allocator, &available, method) catch |err| {
        // Nothing was replaced unless the package manager itself failed midway.
        std.debug.print("Update failed: {s}\n", .{@errorName(err)});
        return error.UpdateFailed;
    };
    defer allocator.free(new_exe);
    std.debug.print("Installed Talkies {s}.\n", .{label});
    // A daemon run by a systemd user unit is restarted; any other running
    // daemon keeps the old version until it is restarted.
    utils.runQuiet(&.{ "systemctl", "--user", "--quiet", "try-restart", "talkies.service" }) catch {};
    std.debug.print("If Talkies is running, quit it from the tray and start it again to use the new version.\n", .{});
}

/// Read a y/N answer from stdin; anything but y/yes is no.
fn confirm(prompt: []const u8) bool {
    std.debug.print("{s}", .{prompt});
    var buf: [16]u8 = undefined;
    const rc = std.os.linux.read(0, &buf, buf.len);
    if (std.os.linux.errno(rc) != .SUCCESS) return false;
    const answer = std.mem.trim(u8, buf[0..rc], &std.ascii.whitespace);
    return std.ascii.eqlIgnoreCase(answer, "y") or std.ascii.eqlIgnoreCase(answer, "yes");
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
        \\  doctor             Check this system (audio, hotkey, paste, tray) and suggest fixes
        \\  quick              Record, transcribe, and paste in one step
        \\  record             Record audio only
        \\  models             Download speech models (Phonon-2 and the Whisper fallback)
        \\  config             Show current configuration
        \\  audio              Test audio recording (5 seconds)
        \\  audio-list         List available input devices
        \\  audio-set <device> Set audio input device
        \\  transcribe [wav]   Transcribe a WAV; TXT/VTT/SRT exports use Whisper timestamps
        \\  history            List saved transcripts [--search TEXT] [--limit N] [--json]
        \\  history clear      Delete every saved transcript
        \\  update [--check]   Check GitHub Releases for a newer build and install it
        \\  version            Print the Talkies version
        \\  help               Show this help message
        \\
        \\Examples:
        \\  talkies daemon                      # Start daemon, press Right Alt to record
        \\  talkies audio-list                  # Show all input devices
        \\  talkies audio-set alsa_input.usb... # Set input device
        \\  talkies quick                       # One-shot recording workflow
        \\  talkies models                      # Download model from config
        \\  talkies transcribe speech.wav --format srt --output speech.srt
        \\  talkies history --search invoice --json
        \\
    ;

    std.debug.print("{s}\n", .{help_text});
}

test "command parsing" {
    try std.testing.expectEqual(Command.quick, parseCommand("quick").?);
    try std.testing.expectEqual(Command.history, parseCommand("history").?);
    try std.testing.expectEqual(Command.update, parseCommand("update").?);
    try std.testing.expectEqual(Command.help, parseCommand("--help").?);
    try std.testing.expectEqual(Command.version, parseCommand("--version").?);
    try std.testing.expect(parseCommand("invalid") == null);
}

test "history arguments" {
    const all = try parseHistoryArgs(&.{});
    try std.testing.expectEqual(history.page_size, all.list.limit);
    try std.testing.expect(all.list.search == null and !all.list.json);

    const query = try parseHistoryArgs(&.{ "--search", "invoice", "--limit", "5", "--json" });
    try std.testing.expectEqualStrings("invoice", query.list.search.?);
    try std.testing.expectEqual(@as(u32, 5), query.list.limit);
    try std.testing.expect(query.list.json);

    try std.testing.expect((try parseHistoryArgs(&.{"clear"})) == .clear);
    try std.testing.expectError(error.MissingArgument, parseHistoryArgs(&.{"--search"}));
    try std.testing.expectError(error.InvalidArgument, parseHistoryArgs(&.{ "--limit", "0" }));
    try std.testing.expectError(error.InvalidArgument, parseHistoryArgs(&.{ "--limit", "lots" }));
    try std.testing.expectError(error.InvalidArgument, parseHistoryArgs(&.{ "clear", "--json" }));
}
