//! Optional DNS-SD advertisement for the Android Talkies companion.
//!
//! Android scans `_ssh._tcp` to find machines it can securely connect to.
//! Publish only when this machine has a non-loopback SSH listener, and let
//! Avahi's child lifetime match the Talkies daemon lifetime. Discovery is an
//! enhancement; missing Avahi/ss must never prevent dictation from starting.

const std = @import("std");
const utils = @import("core").utils;

const default_ssh_port: u16 = 22;

pub const Publisher = struct {
    child: ?std.process.Child = null,

    pub fn start(allocator: std.mem.Allocator) Publisher {
        const port = sshPort() orelse return .{};
        const ss_output = utils.runCapture(allocator, &.{ "ss", "-H", "-ltn" }) catch return .{};
        defer allocator.free(ss_output);
        if (!hasReachableListener(ss_output, port)) return .{};

        const port_text = std.fmt.allocPrintSentinel(allocator, "{d}", .{port}, 0) catch return .{};
        defer allocator.free(port_text);
        const child = std.process.spawn(utils.io(), .{
            .argv = &.{ "avahi-publish-service", "-s", "Talkies", "_ssh._tcp", port_text, "talkies=1" },
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
        }) catch |err| {
            // Avahi is optional on many Linux desktops.
            if (err != error.FileNotFound) utils.logError("Companion discovery unavailable: {}", .{err});
            return .{};
        };
        utils.log("Advertising the SSH host for the Talkies companion on port {d}", .{port});
        return .{ .child = child };
    }

    pub fn stop(self: *Publisher) void {
        if (self.child) |*child| {
            child.kill(utils.io());
            self.child = null;
        }
    }
};

fn sshPort() ?u16 {
    const value = utils.getEnv("TALKIES_SSH_PORT") orelse return default_ssh_port;
    const port = std.fmt.parseInt(u16, value, 10) catch return null;
    return if (port == 0) null else port;
}

fn hasReachableListener(ss_output: []const u8, port: u16) bool {
    var lines = std.mem.tokenizeScalar(u8, ss_output, '\n');
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        _ = fields.next() orelse continue; // state
        _ = fields.next() orelse continue; // recv-q
        _ = fields.next() orelse continue; // send-q
        const local = fields.next() orelse continue;
        const remote = fields.next() orelse continue;
        _ = remote;

        var suffix_buf: [6]u8 = undefined;
        const suffix = std.fmt.bufPrint(&suffix_buf, ":{d}", .{port}) catch continue;
        if (!std.mem.endsWith(u8, local, suffix)) continue;
        const address_with_brackets = local[0 .. local.len - suffix.len];
        const address = if (std.mem.startsWith(u8, address_with_brackets, "[") and
            std.mem.endsWith(u8, address_with_brackets, "]"))
            address_with_brackets[1 .. address_with_brackets.len - 1]
        else
            address_with_brackets;
        if (std.mem.eql(u8, address, "127.0.0.1") or std.mem.eql(u8, address, "::1")) continue;
        return true;
    }
    return false;
}

test "detects only externally reachable SSH listeners" {
    try std.testing.expect(hasReachableListener("LISTEN 0 128 0.0.0.0:22 0.0.0.0:*\n", 22));
    try std.testing.expect(hasReachableListener("LISTEN 0 128 [::]:2222 [::]:*\n", 2222));
    try std.testing.expect(!hasReachableListener("LISTEN 0 128 127.0.0.1:22 0.0.0.0:*\n", 22));
    try std.testing.expect(!hasReachableListener("LISTEN 0 128 [::1]:22 [::]:*\n", 22));
    try std.testing.expect(!hasReachableListener("LISTEN 0 128 0.0.0.0:2200 0.0.0.0:*\n", 22));
}
