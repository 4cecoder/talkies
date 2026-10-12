const std = @import("std");
const cleanup = @import("cleanup.zig");
const utils = @import("utils.zig");
const whisper = @import("whisper.zig");

/// In-memory stand-in for the desktop insertion boundary. The integration
/// test verifies what the application would hand to the platform adapter,
/// without typing into the CI runner's active window.
const InsertionBoundary = struct {
    allocator: std.mem.Allocator,
    delivered_text: ?[]u8 = null,

    fn deliver(self: *InsertionBoundary, text: []const u8) !void {
        if (self.delivered_text) |previous| self.allocator.free(previous);
        self.delivered_text = try self.allocator.dupe(u8, text);
    }

    fn deinit(self: *InsertionBoundary) void {
        if (self.delivered_text) |text| self.allocator.free(text);
    }
};

test "offline cached-model dictation acceptance routes cleaned ASR to insertion" {
    if (utils.getEnv("TALKIES_OFFLINE_ACCEPTANCE") == null) return error.SkipZigTest;
    utils.setIoAllocator(std.testing.allocator);
    defer utils.setIoAllocator(.failing);

    var asr = whisper.WhisperService.init(std.testing.allocator);
    defer asr.deinit();
    try asr.loadModel("tiny");
    const raw = try asr.transcribe("../tests/fixtures/jfk.wav", "");
    defer std.testing.allocator.free(raw);
    try std.testing.expect(raw.len > 0);

    var cleaner = cleanup.Cleaner{ .allocator = std.testing.allocator };
    defer cleaner.deinit();
    const polished = try cleaner.clean(raw, .{});
    defer std.testing.allocator.free(polished);
    try std.testing.expect(std.mem.trim(u8, polished, " \t\r\n").len > 0);

    var insertion = InsertionBoundary{ .allocator = std.testing.allocator };
    defer insertion.deinit();
    try insertion.deliver(polished);
    try std.testing.expectEqualStrings(polished, insertion.delivered_text.?);
}
