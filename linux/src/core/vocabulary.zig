const std = @import("std");

/// Normalize the Linux comma-separated recognition-hints setting into the
/// same prompt representation used by macOS and Windows. ASCII case folding
/// keeps deduplication deterministic without changing user-visible spelling.
pub fn normalizePrompt(allocator: std.mem.Allocator, prompt: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var seen: std.ArrayList([]u8) = .empty;
    defer {
        for (seen.items) |key| allocator.free(key);
        seen.deinit(allocator);
    }

    var terms = std.mem.splitScalar(u8, prompt, ',');
    while (terms.next()) |untrimmed| {
        const term = std.mem.trim(u8, untrimmed, " \t\r\n\x0b\x0c");
        if (term.len == 0) continue;

        const key = try allocator.dupe(u8, term);
        for (key) |*byte| {
            if (byte.* >= 'A' and byte.* <= 'Z') byte.* += 'a' - 'A';
        }
        if (contains(seen.items, key)) {
            allocator.free(key);
            continue;
        }
        seen.append(allocator, key) catch |err| {
            allocator.free(key);
            return err;
        };

        if (output.items.len > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, term);
    }

    return output.toOwnedSlice(allocator);
}

fn contains(values: []const []u8, value: []const u8) bool {
    for (values) |candidate| {
        if (std.mem.eql(u8, candidate, value)) return true;
    }
    return false;
}

test "recognition hints match the shared cross-platform vocabulary fixture" {
    const VocabularyCase = struct {
        terms: []const []const u8,
        expectedPrompt: []const u8,
    };
    const Fixture = struct { cases: []const VocabularyCase };
    const fixture_json = @embedFile("testdata/local-vocabulary-golden.json");
    const parsed = try std.json.parseFromSlice(Fixture, std.testing.allocator, fixture_json, .{});
    defer parsed.deinit();

    for (parsed.value.cases) |test_case| {
        const source = try std.mem.join(std.testing.allocator, ", ", test_case.terms);
        defer std.testing.allocator.free(source);
        const actual = try normalizePrompt(std.testing.allocator, source);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(test_case.expectedPrompt, actual);
    }
}
