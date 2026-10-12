const std = @import("std");

pub const Format = enum { txt, vtt, srt };
pub const Segment = struct {
    start: f64,
    end: f64,
    text: []const u8,
};

pub const Request = struct {
    format: Format,
    output_path: []const u8,
};

pub fn parseFormat(value: []const u8) ?Format {
    if (std.mem.eql(u8, value, "txt")) return .txt;
    if (std.mem.eql(u8, value, "vtt")) return .vtt;
    if (std.mem.eql(u8, value, "srt")) return .srt;
    return null;
}

pub fn parseRequest(args: []const []const u8) !?Request {
    if (args.len == 0) return null;

    var format: ?Format = null;
    var output_path: ?[]const u8 = null;
    var index: usize = 0;
    while (index < args.len) {
        if (std.mem.eql(u8, args[index], "--format") and index + 1 < args.len) {
            format = parseFormat(args[index + 1]) orelse return error.UnsupportedExportFormat;
            index += 2;
        } else if (std.mem.eql(u8, args[index], "--output") and index + 1 < args.len) {
            output_path = args[index + 1];
            index += 2;
        } else {
            return error.InvalidExportArguments;
        }
    }

    if (format == null and output_path == null) return null;
    if (format == null or output_path == null or output_path.?.len == 0) return error.IncompleteExportArguments;
    return .{ .format = format.?, .output_path = output_path.? };
}

pub fn render(allocator: std.mem.Allocator, format: Format, segments: []const Segment) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    if (format == .vtt) try output.appendSlice(allocator, "WEBVTT\n\n");
    for (segments, 0..) |segment, index| {
        switch (format) {
            .txt => {
                try output.append(allocator, '[');
                try appendTimestamp(&output, allocator, segment.start, '.');
                try output.appendSlice(allocator, "] ");
                try output.appendSlice(allocator, segment.text);
                try output.append(allocator, '\n');
            },
            .vtt, .srt => {
                try appendInteger(&output, allocator, index + 1);
                try output.append(allocator, '\n');
                try appendTimestamp(&output, allocator, segment.start, if (format == .srt) ',' else '.');
                try output.appendSlice(allocator, " --> ");
                try appendTimestamp(&output, allocator, segment.end, if (format == .srt) ',' else '.');
                try output.append(allocator, '\n');
                try output.appendSlice(allocator, segment.text);
                try output.appendSlice(allocator, "\n\n");
            },
        }
    }

    return try output.toOwnedSlice(allocator);
}

fn appendTimestamp(output: *std.ArrayList(u8), allocator: std.mem.Allocator, seconds: f64, separator: u8) !void {
    const safe_seconds = @max(seconds, 0);
    const total_milliseconds: u64 = @intFromFloat(@floor(safe_seconds * 1_000 + 0.5));
    const hours = total_milliseconds / 3_600_000;
    const minutes = (total_milliseconds / 60_000) % 60;
    const whole_seconds = (total_milliseconds / 1_000) % 60;
    const milliseconds = total_milliseconds % 1_000;

    try appendPadded(output, allocator, hours, 2);
    try output.append(allocator, ':');
    try appendPadded(output, allocator, minutes, 2);
    try output.append(allocator, ':');
    try appendPadded(output, allocator, whole_seconds, 2);
    try output.append(allocator, separator);
    try appendPadded(output, allocator, milliseconds, 3);
}

fn appendPadded(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u64, width: usize) !void {
    const digits = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(digits);
    var padding = digits.len;
    while (padding < width) : (padding += 1) try output.append(allocator, '0');
    try output.appendSlice(allocator, digits);
}

fn appendInteger(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: usize) !void {
    const digits = try std.fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(digits);
    try output.appendSlice(allocator, digits);
}

test "all export formats match the shared cross-platform golden fixture" {
    const GoldenFixture = struct {
        segments: []const struct {
            timestamp: []const u8,
            text: []const u8,
            start: f64,
            end: f64,
        },
        txt: []const u8,
        vtt: []const u8,
        srt: []const u8,
    };
    const fixture_json = @embedFile("testdata/transcript-export-golden.json");
    const parsed = try std.json.parseFromSlice(GoldenFixture, std.testing.allocator, fixture_json, .{});
    defer parsed.deinit();
    const segments = try std.testing.allocator.alloc(Segment, parsed.value.segments.len);
    defer std.testing.allocator.free(segments);
    for (parsed.value.segments, segments) |source, *target| {
        target.* = .{ .start = source.start, .end = source.end, .text = source.text };
    }

    const cases = [_]struct { format: Format, expected: []const u8 }{
        .{ .format = .txt, .expected = parsed.value.txt },
        .{ .format = .vtt, .expected = parsed.value.vtt },
        .{ .format = .srt, .expected = parsed.value.srt },
    };
    for (cases) |case| {
        const actual = try render(std.testing.allocator, case.format, segments);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(case.expected, actual);
    }
}

test "export format parser accepts only supported formats" {
    try std.testing.expectEqual(Format.txt, parseFormat("txt").?);
    try std.testing.expectEqual(Format.vtt, parseFormat("vtt").?);
    try std.testing.expectEqual(Format.srt, parseFormat("srt").?);
    try std.testing.expect(parseFormat("json") == null);
}

test "export options require a supported format and output path" {
    const options = [_][]const u8{ "--format", "srt", "--output", "speech.srt" };
    const request = (try parseRequest(&options)).?;
    try std.testing.expectEqual(Format.srt, request.format);
    try std.testing.expectEqualStrings("speech.srt", request.output_path);

    try std.testing.expect((try parseRequest(&.{})) == null);
    try std.testing.expectError(error.IncompleteExportArguments, parseRequest(&.{ "--format", "vtt" }));
    try std.testing.expectError(error.UnsupportedExportFormat, parseRequest(&.{ "--format", "json", "--output", "speech.json" }));
}
