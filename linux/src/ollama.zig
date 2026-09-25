const std = @import("std");
const utils = @import("utils.zig");

/// Ollama HTTP client for LLM inference
pub const Client = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    http_client: std.http.Client,

    /// Initialize client with shared Io instance
    pub fn init(allocator: std.mem.Allocator, base_url: []const u8, io: std.Io) Client {
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .http_client = .{
                .allocator = allocator,
                .io = io,
            },
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
    }

    /// Generate a completion from Ollama
    /// Returns the response text, caller must free
    pub fn generate(
        self: *Client,
        model: []const u8,
        prompt: []const u8,
        system_prompt: ?[]const u8,
    ) ![]u8 {
        if (!isLoopbackEndpoint(self.base_url)) return error.NonLocalEndpoint;

        // Escape JSON strings
        const escaped_prompt = try escapeJson(self.allocator, prompt);
        defer self.allocator.free(escaped_prompt);

        // Build JSON request body
        const request_body = if (system_prompt) |sys| blk: {
            const escaped_system = try escapeJson(self.allocator, sys);
            defer self.allocator.free(escaped_system);
            break :blk try std.fmt.allocPrint(
                self.allocator,
                "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"system\":\"{s}\",\"stream\":false}}",
                .{ model, escaped_prompt, escaped_system },
            );
        } else try std.fmt.allocPrint(
            self.allocator,
            "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"stream\":false}}",
            .{ model, escaped_prompt },
        );
        defer self.allocator.free(request_body);

        // Build URL
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/api/generate",
            .{self.base_url},
        );
        defer self.allocator.free(url);

        utils.log("Ollama request to: {s}", .{url});

        // Parse URI
        const uri = try std.Uri.parse(url);

        // Make request
        var req = try self.http_client.request(.POST, uri, .{
            .redirect_behavior = .not_allowed,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = request_body.len };
        try req.sendBodyComplete(request_body);

        // Receive response
        var redirect_buffer: [1024]u8 = undefined;
        var response = try req.receiveHead(&redirect_buffer);

        // Check status
        if (response.head.status != .ok) {
            utils.logError("Ollama returned status: {}", .{response.head.status});
            return error.OllamaRequestFailed;
        }

        // Read response body using Zig 0.16 API
        var transfer_buffer: [4096]u8 = undefined;
        const rdr = response.reader(&transfer_buffer);
        const response_body = try rdr.allocRemaining(self.allocator, .unlimited);
        defer self.allocator.free(response_body);

        utils.log("Ollama response: {s}", .{response_body});

        // Parse JSON response and extract "response" field
        return try parseOllamaResponse(self.allocator, response_body);
    }
};

/// Ollama is a local inference server; transcript text must never be sent to a
/// host outside this machine. Redirects are also disabled on the request.
pub fn isLoopbackEndpoint(endpoint: []const u8) bool {
    const scheme_end = std.mem.indexOf(u8, endpoint, "://") orelse return false;
    const scheme = endpoint[0..scheme_end];
    if (!std.ascii.eqlIgnoreCase(scheme, "http") and !std.ascii.eqlIgnoreCase(scheme, "https")) return false;

    const authority_start = scheme_end + 3;
    const remainder = endpoint[authority_start..];
    const authority_end = std.mem.indexOfAny(u8, remainder, "/?#") orelse remainder.len;
    if (std.mem.indexOfAny(u8, remainder[authority_end..], "?#") != null) return false;
    const authority = remainder[0..authority_end];
    if (authority.len == 0 or std.mem.indexOfAny(u8, authority, "@\\") != null) return false;

    const host: []const u8 = if (authority[0] == '[') blk: {
        const closing = std.mem.indexOfScalar(u8, authority, ']') orelse return false;
        const ipv6 = authority[1..closing];
        const suffix = authority[closing + 1 ..];
        if (!isLoopbackIPv6(ipv6) or !isValidPortSuffix(suffix)) return false;
        break :blk "[loopback-ipv6]";
    } else blk: {
        const colon = std.mem.indexOfScalar(u8, authority, ':');
        const hostname = if (colon) |index| authority[0..index] else authority;
        if (colon) |index| {
            if (!isValidPortSuffix(authority[index..])) return false;
        }
        break :blk hostname;
    };

    if (std.mem.eql(u8, host, "[loopback-ipv6]")) return true;
    const normalized_host = if (std.mem.endsWith(u8, host, ".")) host[0 .. host.len - 1] else host;
    if (std.ascii.eqlIgnoreCase(normalized_host, "localhost")) return true;
    return isLoopbackIPv4(normalized_host);
}

fn isValidPortSuffix(suffix: []const u8) bool {
    if (suffix.len == 0) return true;
    if (suffix[0] != ':' or suffix.len == 1) return false;
    for (suffix[1..]) |character| {
        if (!std.ascii.isDigit(character)) return false;
    }
    _ = std.fmt.parseInt(u16, suffix[1..], 10) catch return false;
    return true;
}

fn isLoopbackIPv6(address: []const u8) bool {
    return std.ascii.eqlIgnoreCase(address, "::1") or
        std.ascii.eqlIgnoreCase(address, "0:0:0:0:0:0:0:1");
}

fn isLoopbackIPv4(address: []const u8) bool {
    var octets = std.mem.splitScalar(u8, address, '.');
    const first = octets.next() orelse return false;
    const second = octets.next() orelse return false;
    const third = octets.next() orelse return false;
    const fourth = octets.next() orelse return false;
    if (octets.next() != null) return false;

    const first_value = std.fmt.parseInt(u8, first, 10) catch return false;
    _ = std.fmt.parseInt(u8, second, 10) catch return false;
    _ = std.fmt.parseInt(u8, third, 10) catch return false;
    _ = std.fmt.parseInt(u8, fourth, 10) catch return false;
    return first_value == 127;
}

test "loopback endpoint validation only accepts local HTTP services" {
    const accepted = [_][]const u8{
        "http://localhost:11434",
        "https://LOCALHOST.:11434/ollama",
        "http://127.0.0.1:11434",
        "http://127.42.1.9:1234",
        "http://[::1]:11434",
        "http://[0:0:0:0:0:0:0:1]:11434",
    };
    for (accepted) |endpoint| {
        try std.testing.expect(isLoopbackEndpoint(endpoint));
    }

    const rejected = [_][]const u8{
        "https://example.com:11434",
        "http://192.168.1.5:11434",
        "http://localhost.example.com:11434",
        "http://user@localhost:11434",
        "http://127.0.0.1:99999",
        "ftp://localhost:11434",
        "localhost:11434",
    };
    for (rejected) |endpoint| {
        try std.testing.expect(!isLoopbackEndpoint(endpoint));
    }
}

test "Ollama client rejects a remote endpoint before making a request" {
    var client = Client.init(std.testing.allocator, "http://192.0.2.1:11434", utils.io());
    defer client.deinit();
    try std.testing.expectError(
        error.NonLocalEndpoint,
        client.generate("model", "transcript text", null),
    );
}

/// Parse Ollama JSON response and extract the "response" field
fn parseOllamaResponse(allocator: std.mem.Allocator, json: []const u8) ![]u8 {
    // Simple JSON parsing - look for "response":"..." field
    const response_start = std.mem.indexOf(u8, json, "\"response\":\"") orelse return error.NoResponseField;
    const value_start = response_start + "\"response\":\"".len;

    // Find the closing quote (handling escaped quotes)
    var i = value_start;
    while (i < json.len) : (i += 1) {
        if (json[i] == '"' and (i == value_start or json[i - 1] != '\\')) {
            // Found closing quote
            const response_text = json[value_start..i];
            // Unescape JSON string
            return try unescapeJson(allocator, response_text);
        }
    }

    return error.InvalidJsonResponse;
}

/// Escape JSON string (handle ", \, newlines, etc.)
fn escapeJson(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    for (s) |ch| {
        switch (ch) {
            '"' => {
                try result.append(allocator, '\\');
                try result.append(allocator, '"');
            },
            '\\' => {
                try result.append(allocator, '\\');
                try result.append(allocator, '\\');
            },
            '\n' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 'n');
            },
            '\r' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 'r');
            },
            '\t' => {
                try result.append(allocator, '\\');
                try result.append(allocator, 't');
            },
            else => try result.append(allocator, ch),
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Unescape JSON string (handle \n, \t, \", \\, etc.)
fn unescapeJson(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < s.len) : (i += 1) {
        if (s[i] == '\\' and i + 1 < s.len) {
            i += 1;
            switch (s[i]) {
                'n' => try result.append(allocator, '\n'),
                't' => try result.append(allocator, '\t'),
                'r' => try result.append(allocator, '\r'),
                '"' => try result.append(allocator, '"'),
                '\\' => try result.append(allocator, '\\'),
                else => {
                    try result.append(allocator, '\\');
                    try result.append(allocator, s[i]);
                },
            }
        } else {
            try result.append(allocator, s[i]);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "unescape JSON" {
    const allocator = std.testing.allocator;

    const input = "Hello\\nWorld\\t!";
    const output = try unescapeJson(allocator, input);
    defer allocator.free(output);

    try std.testing.expectEqualStrings("Hello\nWorld\t!", output);
}
