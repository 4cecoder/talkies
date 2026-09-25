const std = @import("std");
const utils = @import("utils.zig");

pub const max_report_bytes = 32 * 1024;
pub const retained_reports = 5;

/// Formats metadata from a handled top-level error. The optional trace is a
/// Zig error-return trace, never gathered from a signal handler.
pub fn formatReport(
    allocator: std.mem.Allocator,
    error_name: []const u8,
    timestamp_seconds: i64,
    trace: ?*const std.builtin.StackTrace,
) ![]u8 {
    var report: std.ArrayList(u8) = .empty;
    errdefer report.deinit(allocator);

    try appendBounded(&report, allocator, "TALKIES LOCAL ERROR REPORT\nTimestamp (Unix): ");
    const timestamp = try std.fmt.allocPrint(allocator, "{d}\nError: ", .{timestamp_seconds});
    defer allocator.free(timestamp);
    try appendBounded(&report, allocator, timestamp);
    try appendBounded(&report, allocator, error_name);
    try appendBounded(&report, allocator, "\nStack addresses (when available):\n");

    if (trace) |stack| {
        const count = @min(@min(stack.index, stack.instruction_addresses.len), 64);
        for (stack.instruction_addresses[0..count]) |address| {
            const line = try std.fmt.allocPrint(allocator, "0x{x}\n", .{address});
            defer allocator.free(line);
            try appendBounded(&report, allocator, line);
        }
    } else {
        try appendBounded(&report, allocator, "Unavailable in this build or error path.\n");
    }

    return report.toOwnedSlice(allocator);
}

/// Persists one report in a private directory, keeping only five rotating
/// files. Returns false on any filesystem error so diagnostics remain best-effort.
pub fn writeReport(dir: std.Io.Dir, io: std.Io, report: []const u8) bool {
    if (report.len > max_report_bytes) return false;

    var index: usize = retained_reports - 1;
    while (index > 0) {
        index -= 1;
        const destination = slotName(index + 1);
        const source = slotName(index);
        dir.deleteFile(io, &destination) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return false,
        };
        std.Io.Dir.rename(dir, &source, dir, &destination, io) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return false,
        };
    }

    const latest = slotName(0);
    var file = dir.createFile(io, &latest, .{ .permissions = @fromBackingInt(@intCast(0o600)) }) catch return false;
    defer file.close(io);
    file.writeStreamingAll(io, report) catch return false;
    file.setPermissions(io, @fromBackingInt(@intCast(0o600))) catch return false;
    return true;
}

pub fn writeReportAtPath(path: []const u8, report: []const u8) bool {
    var dir = std.Io.Dir.openDirAbsolute(utils.io(), path, .{}) catch return false;
    defer dir.close(utils.io());
    return writeReport(dir, utils.io(), report);
}

/// Best-effort user-data location: `$XDG_DATA_HOME/talkies/diagnostics` or
/// `~/.local/share/talkies/diagnostics`. No network or process monitor is used.
pub fn recordUnhandledError(allocator: std.mem.Allocator, error_name: []const u8, trace: ?*const std.builtin.StackTrace) void {
    const data_dir = utils.getDataDir(allocator) catch return;
    defer allocator.free(data_dir);
    const diagnostic_dir = std.fmt.allocPrint(allocator, "{s}/diagnostics", .{data_dir}) catch return;
    defer allocator.free(diagnostic_dir);
    utils.ensureDir(diagnostic_dir) catch return;

    if (!setPrivateDirectoryPermissions(allocator, diagnostic_dir)) return;

    const report = formatReport(allocator, error_name, utils.realtimeSeconds(), trace) catch return;
    defer allocator.free(report);
    _ = writeReportAtPath(diagnostic_dir, report);
}

fn setPrivateDirectoryPermissions(allocator: std.mem.Allocator, path: []const u8) bool {
    const path_z = utils.dupeZ(allocator, path) catch return false;
    defer allocator.free(path_z);
    return std.c.chmod(path_z, 0o700) == 0;
}

fn slotName(index: usize) [11]u8 {
    // crash-0.log through crash-4.log, with index 0 always the newest.
    var name: [11]u8 = undefined;
    const rendered = std.fmt.bufPrint(&name, "crash-{d}.log", .{index}) catch unreachable;
    std.debug.assert(rendered.len == name.len);
    return name;
}

fn appendBounded(list: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const remaining = max_report_bytes -| list.items.len;
    try list.appendSlice(allocator, value[0..@min(value.len, remaining)]);
}

test "local diagnostics formats bounded metadata and optional stack addresses" {
    const allocator = std.testing.allocator;
    var addresses = [_]usize{ 0xabc, 0xdef };
    const trace = std.builtin.StackTrace{ .index = 2, .instruction_addresses = &addresses };
    const report = try formatReport(allocator, "UnexpectedState", 1_700_000_000, &trace);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "Timestamp (Unix): 1700000000") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Error: UnexpectedState") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "0xabc\n0xdef") != null);
    try std.testing.expect(report.len <= max_report_bytes);
}

test "local diagnostics rotate to five private files" {
    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const io = std.testing.io;

    for (0..7) |offset| {
        const report = try std.fmt.allocPrint(allocator, "report-{d}", .{offset});
        defer allocator.free(report);
        try std.testing.expect(writeReport(temp.dir, io, report));
    }

    for (0..retained_reports) |index| {
        const name = slotName(index);
        try temp.dir.access(io, &name, .{});
    }
    const expired = slotName(retained_reports);
    try std.testing.expectError(error.FileNotFound, temp.dir.access(io, &expired, .{}));
    const oldest_retained = slotName(retained_reports - 1);
    var oldest = try temp.dir.openFile(io, &oldest_retained, .{});
    defer oldest.close(io);
    try std.testing.expectEqual(@as(u64, "report-2".len), (try oldest.stat(io)).size);
    try std.testing.expectEqual(@as(usize, 0o600), @backingInt((try oldest.stat(io)).permissions) & 0o777);
}

test "local diagnostics returns false for an unavailable path" {
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    try std.testing.expect(!writeReportAtPath("/dev/null/not-a-directory", "error report"));
    const oversized: [max_report_bytes + 1]u8 = @splat(0);
    try std.testing.expect(!writeReport(temp.dir, std.testing.io, &oversized));
}

test "local diagnostics makes its directory private" {
    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const path = try std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{temp.sub_path});
    defer allocator.free(path);

    try std.testing.expect(setPrivateDirectoryPermissions(allocator, path));
    const permissions = @backingInt((try temp.dir.stat(std.testing.io)).permissions) & 0o777;
    try std.testing.expectEqual(@as(usize, 0o700), permissions);
}
