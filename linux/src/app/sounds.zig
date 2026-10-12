//! Optional start/stop cues (`[general] sounds = true`). The WAVs are
//! embedded so the installed binary never depends on the working directory.

const std = @import("std");
const utils = @import("core").utils;

pub const Cue = enum { start, stop };

const start_wav = @embedFile("sound_start");
const stop_wav = @embedFile("sound_stop");

/// Fire-and-forget playback on a short-lived thread that reaps the player.
pub fn play(cue: Cue) void {
    const thread = std.Thread.spawn(.{}, playBlocking, .{cue}) catch |err| {
        utils.logDebug("sound thread: {}", .{err});
        return;
    };
    thread.detach();
}

fn playBlocking(cue: Cue) void {
    const allocator = std.heap.smp_allocator;
    const name = switch (cue) {
        .start => "start.wav",
        .stop => "stop.wav",
    };
    const path = utils.privateRuntimePath(allocator, name) catch return;
    defer allocator.free(path);
    if (std.Io.Dir.cwd().access(utils.io(), path, .{})) |_| {} else |_| {
        const bytes = switch (cue) {
            .start => start_wav,
            .stop => stop_wav,
        };
        std.Io.Dir.cwd().writeFile(utils.io(), .{ .sub_path = path, .data = bytes }) catch |err| {
            utils.logDebug("sound cache: {}", .{err});
            return;
        };
    }
    const players = [_][]const []const u8{
        &.{ "pw-play", path },
        &.{ "paplay", path },
        &.{ "aplay", "-q", path },
    };
    for (players) |argv| {
        utils.runQuiet(argv) catch continue;
        return;
    }
}
