//! Speech recognizer chain: Phonon-2 first, whisper.cpp as fallback.
//!
//! Owns both services and their lifecycle. The order comes from
//! speech_policy.zig; this file only adapts the services to it. Whisper is
//! loaded lazily when Phonon-2 is primary, so only one model sits in memory
//! until a fallback actually happens.

const std = @import("std");
const utils = @import("core").utils;
const policy = @import("speech_policy.zig");
const phonon = @import("phonon.zig");
const whisper = @import("whisper.zig");

pub const Preference = policy.Preference;
pub const Backend = policy.Backend;
pub const Plan = policy.Plan;

pub const Transcript = struct {
    /// Owned by the recognizer's allocator.
    text: []u8,
    backend: Backend,
};

pub const Recognizer = struct {
    allocator: std.mem.Allocator,
    whisper: whisper.WhisperService,
    phonon: phonon.PhononService,
    preference: Preference = .auto,
    language: [16]u8 = @splat(0),
    language_len: usize = 0,
    whisper_model: [16]u8 = @splat(0),
    whisper_model_len: usize = 0,
    /// Whisper model currently in memory (empty when none).
    loaded_whisper: [16]u8 = @splat(0),
    loaded_whisper_len: usize = 0,
    /// Set when Phonon-2 failed to load; cleared by configure()/prepare().
    /// Avoids re-reading 674 MB on every dictation after a failure.
    phonon_load_failed: bool = false,
    last_backend: ?Backend = null,

    pub fn init(allocator: std.mem.Allocator) Recognizer {
        return .{
            .allocator = allocator,
            .whisper = whisper.WhisperService.init(allocator),
            .phonon = phonon.PhononService.init(allocator),
        };
    }

    pub fn deinit(self: *Recognizer) void {
        self.phonon.deinit();
        self.whisper.deinit();
    }

    pub fn languageCode(self: *const Recognizer) []const u8 {
        return self.language[0..self.language_len];
    }

    pub fn whisperModel(self: *const Recognizer) []const u8 {
        return self.whisper_model[0..self.whisper_model_len];
    }

    /// Apply settings. Returns true when a loaded model no longer matches
    /// and prepare() should run again.
    pub fn configure(self: *Recognizer, preference: Preference, whisper_model: []const u8, language: []const u8, requested_threads: u8) bool {
        const threads = std.math.clamp(requested_threads, 1, 64);
        const lang = std.mem.trim(u8, language, &std.ascii.whitespace);
        const lang_len = @min(lang.len, self.language.len);
        const model_len = @min(whisper_model.len, self.whisper_model.len);
        const changed = preference != self.preference or
            !std.mem.eql(u8, self.languageCode(), lang[0..lang_len]) or
            !std.mem.eql(u8, self.whisperModel(), whisper_model[0..model_len]) or
            threads != self.phonon.threads;

        self.preference = preference;
        @memcpy(self.language[0..lang_len], lang[0..lang_len]);
        self.language_len = lang_len;
        @memcpy(self.whisper_model[0..model_len], whisper_model[0..model_len]);
        self.whisper_model_len = model_len;
        self.whisper.configure(language, threads);
        if (threads != self.phonon.threads) {
            self.phonon.threads = threads;
            self.phonon.unload();
        }
        if (changed) self.phonon_load_failed = false;
        return changed;
    }

    /// Why the last Phonon-2 load failed, while that failure is latched.
    pub fn phononFailure(self: *const Recognizer) ?[]const u8 {
        return if (self.phonon_load_failed) self.phonon.lastError() else null;
    }

    pub fn currentPlan(self: *const Recognizer) Plan {
        return policy.plan(self.preference, self.languageCode(), self.phonon.store().isInstalled());
    }

    /// Load the primary recognizer. With Phonon-2 primary, Whisper's model
    /// file is still made available (downloaded once, as on first run) so a
    /// fallback works offline, but it is only loaded into memory on demand.
    /// Fails only if no recognizer can be made ready.
    pub fn prepare(self: *Recognizer) !Backend {
        self.phonon_load_failed = false;
        const p = self.currentPlan();
        if (p.primary() == .phonon) {
            if (self.loadPhonon()) {
                self.unloadWhisper();
                self.whisper.downloadModel(self.whisperModel()) catch |err| {
                    utils.logError("Whisper fallback model unavailable: {}", .{err});
                };
                return .phonon;
            } else |_| {}
        } else {
            self.phonon.unload();
            if (p.phonon_skipped) |reason| utils.log("Using Whisper: {s}", .{reason.describe()});
        }
        try self.ensureWhisper();
        return .whisper;
    }

    fn ensureWhisper(self: *Recognizer) !void {
        const name = self.whisperModel();
        if (self.whisper.ctx != null and std.mem.eql(u8, self.loaded_whisper[0..self.loaded_whisper_len], name)) return;
        self.loaded_whisper_len = 0;
        try self.whisper.loadModel(name);
        @memcpy(self.loaded_whisper[0..name.len], name);
        self.loaded_whisper_len = name.len;
    }

    fn unloadWhisper(self: *Recognizer) void {
        // deinit() frees the context and path; language and threads stay.
        self.whisper.deinit();
        self.loaded_whisper_len = 0;
    }

    fn loadPhonon(self: *Recognizer) !void {
        if (self.phonon.isLoaded()) return;
        if (self.phonon_load_failed) return error.PhononLoadFailed;
        self.phonon.load() catch |err| {
            self.phonon_load_failed = true;
            utils.logError("Phonon-2 unavailable ({s}): {s}; using Whisper", .{ @errorName(err), self.phonon.lastError() });
            return err;
        };
    }

    /// Transcribe with the first recognizer in the plan that succeeds.
    pub fn transcribe(self: *Recognizer, audio_path: []const u8, vocabulary_prompt: []const u8) !Transcript {
        const p = self.currentPlan();
        var runner: Runner = .{ .recognizer = self, .audio_path = audio_path, .vocabulary_prompt = vocabulary_prompt };
        const outcome = try policy.runChain([]u8, &p, &runner);
        self.last_backend = outcome.backend;
        return .{ .text = outcome.value, .backend = outcome.backend };
    }

    const Runner = struct {
        recognizer: *Recognizer,
        audio_path: []const u8,
        vocabulary_prompt: []const u8,

        pub fn run(self: *Runner, backend: Backend) ![]u8 {
            const r = self.recognizer;
            switch (backend) {
                .phonon => {
                    try r.loadPhonon();
                    return r.phonon.transcribe(self.audio_path) catch |err| {
                        utils.logError("Phonon-2 transcription failed: {s}", .{r.phonon.lastError()});
                        return err;
                    };
                },
                .whisper => {
                    try r.ensureWhisper();
                    const text = try r.whisper.transcribe(self.audio_path, self.vocabulary_prompt);
                    return @constCast(text);
                },
            }
        }

        pub fn fallback(self: *Runner, backend: Backend, err: anyerror) void {
            _ = self;
            utils.log("{s} failed ({s}); falling back to Whisper", .{ backend.displayName(), @errorName(err) });
        }
    };
};

test "recognizer configure reports changes and keeps the Whisper fallback name" {
    var recognizer = Recognizer.init(std.testing.allocator);
    defer recognizer.deinit();
    try std.testing.expect(recognizer.configure(.auto, "base", " en ", 4));
    try std.testing.expectEqualStrings("en", recognizer.languageCode());
    try std.testing.expectEqualStrings("base", recognizer.whisperModel());
    try std.testing.expect(!recognizer.configure(.auto, "base", "en", 4));
    try std.testing.expect(recognizer.configure(.whisper, "base", "en", 4));
    try std.testing.expectEqual(@as(?policy.SkipReason, .whisper_selected), recognizer.currentPlan().phonon_skipped);
    try std.testing.expect(recognizer.configure(.whisper, "small", "en", 4));
    try std.testing.expect(recognizer.configure(.whisper, "small", "de", 4));
}
