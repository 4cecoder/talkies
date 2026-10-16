//! Speech-recognizer selection and fallback policy.
//!
//! Phonon-2 (CrispASR) is the preferred recognizer and whisper.cpp is the
//! fallback. This file decides the order to try them in and runs that order;
//! it owns no runtime, so the policy is testable without either library.

const std = @import("std");

/// What the user asked for (`[transcription] speech_engine`).
pub const Preference = enum {
    /// Phonon-2 when it is installed and the language is English, else Whisper.
    auto,
    /// Phonon-2 whenever it can run (also for language "auto"), Whisper as fallback.
    phonon,
    /// Whisper only.
    whisper,
};

pub const Backend = enum {
    phonon,
    whisper,

    pub fn displayName(self: Backend) []const u8 {
        return switch (self) {
            .phonon => "Phonon-2",
            .whisper => "Whisper",
        };
    }
};

/// Why Phonon-2 is not part of a plan.
pub const SkipReason = enum {
    /// The user chose Whisper.
    whisper_selected,
    /// Phonon-2 is English-only and the configured language is not English.
    language_not_english,
    /// Language detection ("auto") is configured; only Whisper can detect.
    language_detection,
    /// The Phonon-2 model has not been downloaded.
    not_installed,

    pub fn describe(self: SkipReason) []const u8 {
        return switch (self) {
            .whisper_selected => "Whisper is selected",
            .language_not_english => "Phonon-2 is English-only",
            .language_detection => "language detection needs Whisper",
            .not_installed => "Phonon-2 is not downloaded",
        };
    }
};

/// Recognizers to try, in order. Whisper is always last.
pub const Plan = struct {
    buffer: [2]Backend = undefined,
    len: usize = 0,
    phonon_skipped: ?SkipReason = null,

    pub fn backends(self: *const Plan) []const Backend {
        return self.buffer[0..self.len];
    }

    pub fn primary(self: *const Plan) Backend {
        return self.buffer[0];
    }

    fn whisperOnly(reason: SkipReason) Plan {
        return .{ .buffer = .{ .whisper, undefined }, .len = 1, .phonon_skipped = reason };
    }
};

/// True for "en" and regional English tags ("en-US", "en_GB"), any case.
pub fn isEnglish(language: []const u8) bool {
    const lang = std.mem.trim(u8, language, &std.ascii.whitespace);
    if (lang.len < 2 or !std.ascii.eqlIgnoreCase(lang[0..2], "en")) return false;
    return lang.len == 2 or lang[2] == '-' or lang[2] == '_';
}

fn isDetect(language: []const u8) bool {
    const lang = std.mem.trim(u8, language, &std.ascii.whitespace);
    return lang.len == 0 or std.ascii.eqlIgnoreCase(lang, "auto");
}

pub fn plan(preference: Preference, language: []const u8, phonon_installed: bool) Plan {
    if (preference == .whisper) return Plan.whisperOnly(.whisper_selected);
    if (isDetect(language)) {
        // Choosing Phonon-2 explicitly says "I speak English".
        if (preference == .auto) return Plan.whisperOnly(.language_detection);
    } else if (!isEnglish(language)) {
        return Plan.whisperOnly(.language_not_english);
    }
    if (!phonon_installed) return Plan.whisperOnly(.not_installed);
    return .{ .buffer = .{ .phonon, .whisper }, .len = 2 };
}

pub fn Outcome(comptime T: type) type {
    return struct { value: T, backend: Backend };
}

/// Try each backend in `p` until one succeeds. `runner` provides
/// `run(Backend) !T` and `fallback(Backend, anyerror) void`, which is called
/// for every failure that another backend will retry. The last backend's
/// error is returned unchanged.
pub fn runChain(comptime T: type, p: *const Plan, runner: anytype) !Outcome(T) {
    const order = p.backends();
    std.debug.assert(order.len > 0);
    for (order, 0..) |backend, index| {
        if (runner.run(backend)) |value| {
            return .{ .value = value, .backend = backend };
        } else |err| {
            if (index + 1 == order.len) return err;
            runner.fallback(backend, err);
        }
    }
    unreachable;
}

test "auto prefers Phonon-2 for English when installed, with Whisper behind it" {
    const p = plan(.auto, "en", true);
    try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, p.backends());
    try std.testing.expectEqual(Backend.phonon, p.primary());
    try std.testing.expectEqual(@as(?SkipReason, null), p.phonon_skipped);
    try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, plan(.auto, " EN-us ", true).backends());
    try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, plan(.auto, "en_GB", true).backends());
}

test "auto falls back to Whisper when Phonon-2 cannot serve the request" {
    inline for (.{
        .{ "en", false, SkipReason.not_installed },
        .{ "de", true, SkipReason.language_not_english },
        .{ "eng", true, SkipReason.language_not_english },
        .{ "auto", true, SkipReason.language_detection },
        .{ "", true, SkipReason.language_detection },
    }) |case| {
        const p = plan(.auto, case[0], case[1]);
        try std.testing.expectEqualSlices(Backend, &.{.whisper}, p.backends());
        try std.testing.expectEqual(@as(?SkipReason, case[2]), p.phonon_skipped);
    }
}

test "explicit Phonon-2 accepts language detection but never non-English" {
    try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, plan(.phonon, "auto", true).backends());
    try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, plan(.phonon, "en", true).backends());
    const german = plan(.phonon, "de", true);
    try std.testing.expectEqualSlices(Backend, &.{.whisper}, german.backends());
    try std.testing.expectEqual(@as(?SkipReason, .language_not_english), german.phonon_skipped);
    try std.testing.expectEqual(@as(?SkipReason, .not_installed), plan(.phonon, "en", false).phonon_skipped);
}

test "whisper preference never plans Phonon-2" {
    const p = plan(.whisper, "en", true);
    try std.testing.expectEqualSlices(Backend, &.{.whisper}, p.backends());
    try std.testing.expectEqual(@as(?SkipReason, .whisper_selected), p.phonon_skipped);
}

test "isEnglish accepts only English tags" {
    try std.testing.expect(isEnglish("en"));
    try std.testing.expect(isEnglish("En-Au"));
    try std.testing.expect(!isEnglish("e"));
    try std.testing.expect(!isEnglish("es"));
    try std.testing.expect(!isEnglish("english"));
}

const FakeRunner = struct {
    phonon_error: ?anyerror = null,
    whisper_error: ?anyerror = null,
    calls: [4]Backend = undefined,
    call_count: usize = 0,
    fallbacks: usize = 0,
    last_fallback_error: ?anyerror = null,

    fn run(self: *FakeRunner, backend: Backend) ![]const u8 {
        self.calls[self.call_count] = backend;
        self.call_count += 1;
        switch (backend) {
            .phonon => if (self.phonon_error) |err| return err else return "from phonon",
            .whisper => if (self.whisper_error) |err| return err else return "from whisper",
        }
    }

    fn fallback(self: *FakeRunner, backend: Backend, err: anyerror) void {
        std.debug.assert(backend == .phonon);
        self.fallbacks += 1;
        self.last_fallback_error = err;
    }
};

test "chain uses Phonon-2 and never touches Whisper when Phonon-2 succeeds" {
    var runner: FakeRunner = .{};
    const p = plan(.auto, "en", true);
    const outcome = try runChain([]const u8, &p, &runner);
    try std.testing.expectEqual(Backend.phonon, outcome.backend);
    try std.testing.expectEqualStrings("from phonon", outcome.value);
    try std.testing.expectEqualSlices(Backend, &.{.phonon}, runner.calls[0..runner.call_count]);
    try std.testing.expectEqual(@as(usize, 0), runner.fallbacks);
}

test "chain falls back to Whisper when Phonon-2 fails to load or transcribe" {
    for ([_]anyerror{ error.PhononLoadFailed, error.PhononTranscriptionFailed }) |failure| {
        var runner: FakeRunner = .{ .phonon_error = failure };
        const p = plan(.auto, "en", true);
        const outcome = try runChain([]const u8, &p, &runner);
        try std.testing.expectEqual(Backend.whisper, outcome.backend);
        try std.testing.expectEqualStrings("from whisper", outcome.value);
        try std.testing.expectEqualSlices(Backend, &.{ .phonon, .whisper }, runner.calls[0..runner.call_count]);
        try std.testing.expectEqual(@as(usize, 1), runner.fallbacks);
        try std.testing.expectEqual(@as(?anyerror, failure), runner.last_fallback_error);
    }
}

test "chain reports the Whisper error when every backend fails" {
    var runner: FakeRunner = .{ .phonon_error = error.PhononLoadFailed, .whisper_error = error.TranscriptionFailed };
    const p = plan(.auto, "en", true);
    try std.testing.expectError(error.TranscriptionFailed, runChain([]const u8, &p, &runner));
    try std.testing.expectEqual(@as(usize, 2), runner.call_count);
}

test "whisper-only chain runs Whisper once with no fallback" {
    var runner: FakeRunner = .{ .whisper_error = error.TranscriptionFailed };
    const p = plan(.whisper, "en", true);
    try std.testing.expectError(error.TranscriptionFailed, runChain([]const u8, &p, &runner));
    try std.testing.expectEqualSlices(Backend, &.{.whisper}, runner.calls[0..runner.call_count]);
    try std.testing.expectEqual(@as(usize, 0), runner.fallbacks);
}
