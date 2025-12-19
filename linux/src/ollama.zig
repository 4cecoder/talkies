const std = @import("std");
const utils = @import("utils.zig");

/// Ollama HTTP client for LLM inference
pub const Client = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    http_client: std.http.Client,
    io_threaded: std.Io.Threaded,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) Client {
        var io_threaded = std.Io.Threaded.init(allocator);
        return .{
            .allocator = allocator,
            .base_url = base_url,
            .io_threaded = io_threaded,
            .http_client = .{
                .allocator = allocator,
                .io = io_threaded.io(),
            },
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
        self.io_threaded.deinit();
    }

    /// Generate a completion from Ollama
    /// Returns the response text, caller must free
    pub fn generate(
        self: *Client,
        model: []const u8,
        prompt: []const u8,
        system_prompt: ?[]const u8,
    ) ![]u8 {
        // Build JSON request body
        const request_body = if (system_prompt) |sys|
            try std.fmt.allocPrint(
                self.allocator,
                "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"system\":\"{s}\",\"stream\":false}}",
                .{ model, prompt, sys },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "{{\"model\":\"{s}\",\"prompt\":\"{s}\",\"stream\":false}}",
                .{ model, prompt },
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

        // Allocate buffer for response (1MB max)
        const response_buffer = try self.allocator.alloc(u8, 1024 * 1024);
        defer self.allocator.free(response_buffer);

        // Create a fixed buffer writer
        var writer = std.Io.Writer.fixed(response_buffer);

        const result = try self.http_client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = request_body,
            .response_writer = &writer,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
            },
        });

        if (result.status != .ok) {
            utils.logError("Ollama returned status: {}", .{result.status});
            return error.OllamaRequestFailed;
        }

        const response_body = writer.buffered();
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
