const std = @import("std");
const audio = @import("audio.zig");
const whisper = @import("whisper.zig");
const clipboard = @import("clipboard.zig");
const input = @import("input.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

const Command = enum {
    quick,
    record,
    models_download,
    config_show,
    audio_test,
    help,
};

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
        .{ "help", .help },
        .{ "--help", .help },
        .{ "-h", .help },
    });

    return command_map.get(arg);
}

fn runQuick(allocator: std.mem.Allocator) !void {
    utils.log("Starting quick recording workflow...", .{});

    // TODO: Implement full workflow
    // 1. Start recording
    // 2. Wait for Ctrl+C
    // 3. Stop recording and save to WAV
    // 4. Transcribe with whisper
    // 5. Copy to clipboard
    // 6. Auto-paste
    // 7. Cleanup

    _ = allocator;
    std.debug.print("Quick mode not yet implemented\n", .{});
}

fn runRecord(allocator: std.mem.Allocator) !void {
    utils.log("Recording audio...", .{});

    // TODO: Implement audio recording only
    _ = allocator;
    std.debug.print("Record mode not yet implemented\n", .{});
}

fn runModelsDownload(allocator: std.mem.Allocator) !void {
    utils.log("Downloading whisper models...", .{});

    // TODO: Implement model download
    _ = allocator;
    std.debug.print("Model download not yet implemented\n", .{});
}

fn runConfigShow(allocator: std.mem.Allocator) !void {
    utils.log("Configuration:", .{});

    // TODO: Load and display config
    _ = allocator;
    std.debug.print("Config display not yet implemented\n", .{});
}

fn runAudioTest(allocator: std.mem.Allocator) !void {
    utils.log("Testing audio devices...", .{});

    // TODO: Implement audio device test
    _ = allocator;
    std.debug.print("Audio test not yet implemented\n", .{});
}

fn printHelp() !void {
    const help_text =
        \\Talkies - Voice transcription and text insertion
        \\
        \\Usage:
        \\  talkies <command>
        \\
        \\Commands:
        \\  quick              Record, transcribe, and paste in one step
        \\  record             Record audio only
        \\  models             Download whisper models
        \\  config             Show current configuration
        \\  audio              Test audio devices
        \\  help               Show this help message
        \\
        \\Examples:
        \\  talkies quick      # Start recording, press Ctrl+C to stop and transcribe
        \\  talkies record     # Record audio to file
        \\  talkies models     # Download base whisper model
        \\
    ;

    std.debug.print("{s}\n", .{help_text});
}

test "command parsing" {
    try std.testing.expectEqual(Command.quick, parseCommand("quick").?);
    try std.testing.expectEqual(Command.help, parseCommand("--help").?);
    try std.testing.expect(parseCommand("invalid") == null);
}
