//! The daemon's single source of truth for "what is Talkies doing right now".
//!
//! Every user-visible surface (dictation window, tray, WebSocket clients,
//! status monitor) is derived from one `Phase`, and phase changes only happen
//! through `Daemon.enter`, which consults `allowed` below. This replaces a set
//! of independent flags (capture/stopping/job/yap/hide timer) that could drift
//! out of sync.

const std = @import("std");

pub const Phase = enum {
    /// Loading the Whisper model; hotkeys are ignored.
    starting,
    /// Ready for a new recording.
    idle,
    /// Capturing audio.
    recording,
    /// Stop requested; capturing the short tail so last words aren't clipped.
    stopping,
    /// Transcribing / enhancing / inserting on the worker thread.
    processing,
    /// YAP refinement window is open (opt-in).
    yap,
    /// Just finished; the "Done!" window is visible until it auto-hides.
    complete,
    /// Something failed; the error is visible until it auto-hides.
    failed,

    /// A new recording may start from here.
    pub fn canStartRecording(self: Phase) bool {
        return switch (self) {
            .idle, .complete, .failed, .yap => true,
            .starting, .recording, .stopping, .processing => false,
        };
    }

    /// Settings may be swapped in (no thread is reading the config).
    pub fn isQuiescent(self: Phase) bool {
        return switch (self) {
            .idle, .complete, .failed, .yap => true,
            .starting, .recording, .stopping, .processing => false,
        };
    }

    /// Coarse state published to WebSocket clients (stable public contract).
    pub fn publicState(self: Phase) []const u8 {
        return switch (self) {
            .starting, .idle, .complete, .failed => "idle",
            .recording, .stopping => "recording",
            .processing => "processing",
            .yap => "yap_refining",
        };
    }
};

/// Legal transitions. Anything else is a programming error and is refused
/// (and logged) instead of corrupting the UI.
pub fn allowed(from: Phase, to: Phase) bool {
    if (from == to) return true;
    return switch (to) {
        .starting => from == .starting or from.isQuiescent(), // (re)loading the model
        .idle => true, // dismiss/auto-hide, cancel, model loaded
        .recording => from.canStartRecording(),
        .stopping => from == .recording,
        .processing => from == .stopping or from == .recording,
        .yap => from == .processing or from == .yap,
        .complete => from == .processing or from == .yap,
        .failed => true,
    };
}

test "normal dictation path is allowed" {
    const path = [_]Phase{ .starting, .idle, .recording, .stopping, .processing, .complete, .idle };
    for (path[0 .. path.len - 1], path[1..]) |from, to| {
        try std.testing.expect(allowed(from, to));
    }
}

test "cannot start recording while busy" {
    try std.testing.expect(!allowed(.processing, .recording));
    try std.testing.expect(!allowed(.stopping, .recording));
    try std.testing.expect(!allowed(.starting, .recording));
    try std.testing.expect(allowed(.complete, .recording)); // press again right after Done!
    try std.testing.expect(allowed(.yap, .recording)); // append to YAP session
}

test "stop only from recording; model reload only when quiescent" {
    try std.testing.expect(!allowed(.idle, .stopping));
    try std.testing.expect(allowed(.idle, .starting));
    try std.testing.expect(!allowed(.processing, .starting));
    try std.testing.expect(allowed(.recording, .failed));
}

test "public state mapping is stable" {
    try std.testing.expectEqualStrings("recording", Phase.stopping.publicState());
    try std.testing.expectEqualStrings("idle", Phase.failed.publicState());
    try std.testing.expectEqualStrings("yap_refining", Phase.yap.publicState());
}
