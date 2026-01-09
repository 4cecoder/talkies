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
    var result: std.ArrayList(u8) = .{};
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
    var result: std.ArrayList(u8) = .{};
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
