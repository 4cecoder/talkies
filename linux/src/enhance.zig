//! LLM text enhancement via local Ollama or LM Studio servers.
//!
//! Ports the macOS `OllamaPlugin` / `LMStudioPlugin` behaviour: the same five
//! preset modes with identical system prompts, the same request parameters,
//! and the same fallbacks (empty LLM output keeps the raw transcript).
//! Requests are only ever sent to loopback endpoints.

const std = @import("std");
const utils = @import("utils.zig");
const ollama = @import("ollama.zig");
const config = @import("config.zig");

pub const Mode = enum {
    grammar,
    technical,
    concise,
    creative,
    companion,

    pub const all = [_]Mode{ .grammar, .technical, .concise, .creative, .companion };

    /// Matches the macOS raw values, which is what macOS persists once a
    /// user picks a mode.
    pub fn displayName(self: Mode) []const u8 {
        return switch (self) {
            .grammar => "Grammar & Clarity",
            .technical => "Technical Writing",
            .concise => "Concise & Professional",
            .creative => "Creative Enhancement",
            .companion => "AI Companion",
        };
    }

    pub fn description(self: Mode) []const u8 {
        return switch (self) {
            .grammar => "Fix grammar, spelling, and clarity while preserving your exact meaning",
            .technical => "Optimize for code comments, documentation, and technical communication",
            .concise => "Remove filler words and make text more professional and concise",
            .creative => "Enhance flow and engagement while maintaining your intent",
            .companion => "Talk to a caring, supportive AI companion who responds with warmth and empathy",
        };
    }

    /// Accepts either the short tag ("grammar") or the macOS display name
    /// ("Grammar & Clarity"); anything else falls back to grammar, as on macOS.
    pub fn parse(value: []const u8) Mode {
        if (std.meta.stringToEnum(Mode, value)) |mode| return mode;
        for (all) |mode| {
            if (std.ascii.eqlIgnoreCase(value, mode.displayName())) return mode;
        }
        return .grammar;
    }

    pub fn systemPrompt(self: Mode) []const u8 {
        return switch (self) {
            .grammar =>
            \\You are a text cleanup tool. Your ONLY job is to fix grammar, spelling, and punctuation errors in the input text.
            \\
            \\CRITICAL RULES:
            \\- Output ONLY the corrected text
            \\- Do NOT answer questions in the text
            \\- Do NOT add any commentary or explanations
            \\- Do NOT change the meaning or intent
            \\- Preserve the original tone and style
            \\- If the text is a question, return the corrected question
            \\
            \\Input → Output (nothing else)
            ,
            .technical =>
            \\You are a text cleanup tool for technical writing. Fix grammar, use proper technical terminology, and improve clarity.
            \\
            \\CRITICAL RULES:
            \\- Output ONLY the corrected text
            \\- Do NOT answer questions or explain concepts
            \\- Do NOT add commentary
            \\- Preserve the original meaning exactly
            \\- Optimize for code comments and documentation style
            \\
            \\Input → Output (nothing else)
            ,
            .concise =>
            \\You are a text cleanup tool. Make the input text concise and professional.
            \\
            \\CRITICAL RULES:
            \\- Output ONLY the improved text
            \\- Do NOT answer questions in the text
            \\- Do NOT add any explanation or commentary
            \\- Remove filler words and redundancy
            \\- Preserve the core meaning
            \\
            \\Input → Output (nothing else)
            ,
            .creative =>
            \\You are a text cleanup tool. Enhance the flow and engagement of the input text while fixing grammar.
            \\
            \\CRITICAL RULES:
            \\- Output ONLY the enhanced text
            \\- Do NOT answer questions or respond to content
            \\- Do NOT add commentary
            \\- Maintain the original intent
            \\
            \\Input → Output (nothing else)
            ,
            .companion =>
            \\You are a conversational AI companion. Respond naturally and warmly to what the user says.
            \\
            \\Style: Casual, friendly, use contractions (I'm, you're, that's). Keep responses brief (1-2 sentences). Be genuine and empathetic.
            \\
            \\Avoid: Formal language, long responses, robotic tone, excessive positivity.
            ,
        };
    }
};

pub const Error = error{
    NonLocalEndpoint,
    ServerError,
    InvalidResponse,
    NoModelAvailable,
};

/// Run the configured LLM enhancer. Returns an owned copy of the enhanced
/// text, or of `text` itself when the model returns nothing.
pub fn enhance(allocator: std.mem.Allocator, cfg: *const config.Config, text: []const u8) ![]u8 {
    return switch (cfg.enhancer) {
        .ollama => enhanceOllama(allocator, cfg, text),
        .lm_studio => enhanceLmStudio(allocator, cfg, text),
        .none, .s1_mini => allocator.dupe(u8, text),
    };
}

const OllamaOptions = struct {
    temperature: f64,
    top_p: f64,
    top_k: u32,
    repeat_penalty: f64,
    num_ctx: u32,
    num_predict: u32,
};

const OllamaRequest = struct {
    model: []const u8,
    prompt: []const u8,
    system: []const u8,
    stream: bool = false,
    options: OllamaOptions,
    stop: ?[]const []const u8,
};

fn enhanceOllama(allocator: std.mem.Allocator, cfg: *const config.Config, text: []const u8) ![]u8 {
    const system_prompt = if (cfg.ollama_use_custom_prompt and cfg.ollama_custom_system_prompt.len > 0)
        cfg.ollama_custom_system_prompt
    else
        Mode.parse(cfg.ollama_enhancement_mode).systemPrompt();

    var stops: std.ArrayList([]const u8) = .empty;
    defer stops.deinit(allocator);
    var it = std.mem.splitScalar(u8, cfg.ollama_stop_sequences, ',');
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, &std.ascii.whitespace);
        if (trimmed.len > 0) try stops.append(allocator, trimmed);
    }

    const body = try std.json.Stringify.valueAlloc(allocator, OllamaRequest{
        .model = cfg.ollama_selected_model,
        .prompt = text,
        .system = system_prompt,
        .options = .{
            .temperature = cfg.ollama_temperature,
            .top_p = cfg.ollama_top_p,
            .top_k = cfg.ollama_top_k,
            .repeat_penalty = cfg.ollama_repeat_penalty,
            .num_ctx = cfg.ollama_context_length,
            .num_predict = cfg.ollama_max_tokens,
        },
        .stop = if (stops.items.len > 0) stops.items else null,
    }, .{ .emit_null_optional_fields = false });
    defer allocator.free(body);

    const response = try request(allocator, cfg.ollama_host, "/api/generate", body);
    defer allocator.free(response);

    const Parsed = struct { response: []const u8 };
    const parsed = std.json.parseFromSlice(Parsed, allocator, response, .{ .ignore_unknown_fields = true }) catch
        return Error.InvalidResponse;
    defer parsed.deinit();

    return keepOrReplace(allocator, text, parsed.value.response);
}

const ChatMessage = struct { role: []const u8, content: []const u8 };

const LmStudioRequest = struct {
    model: []const u8,
    messages: []const ChatMessage,
    temperature: f64,
    top_p: f64,
    max_tokens: u32,
    stream: bool = false,
};

fn enhanceLmStudio(allocator: std.mem.Allocator, cfg: *const config.Config, text: []const u8) ![]u8 {
    // macOS auto-selects the first available model when none is chosen.
    var owned_model: ?[]u8 = null;
    defer if (owned_model) |m| allocator.free(m);
    const model = if (cfg.lm_studio_selected_model.len > 0) cfg.lm_studio_selected_model else blk: {
        var models = try listModels(allocator, .lm_studio, cfg.lm_studio_endpoint);
        defer models.deinit();
        if (models.names.len == 0) return Error.NoModelAvailable;
        owned_model = try allocator.dupe(u8, models.names[0]);
        break :blk owned_model.?;
    };

    const messages = [_]ChatMessage{
        .{ .role = "system", .content = Mode.parse(cfg.lm_studio_enhancement_mode).systemPrompt() },
        .{ .role = "user", .content = text },
    };
    const body = try std.json.Stringify.valueAlloc(allocator, LmStudioRequest{
        .model = model,
        .messages = &messages,
        .temperature = cfg.lm_studio_temperature,
        .top_p = cfg.lm_studio_top_p,
        .max_tokens = cfg.lm_studio_max_tokens,
    }, .{});
    defer allocator.free(body);

    const response = try request(allocator, cfg.lm_studio_endpoint, "/v1/chat/completions", body);
    defer allocator.free(response);

    const Parsed = struct {
        choices: []const struct {
            message: struct { content: []const u8 },
        },
    };
    const parsed = std.json.parseFromSlice(Parsed, allocator, response, .{ .ignore_unknown_fields = true }) catch
        return Error.InvalidResponse;
    defer parsed.deinit();
    if (parsed.value.choices.len == 0) return Error.InvalidResponse;

    return keepOrReplace(allocator, text, parsed.value.choices[0].message.content);
}

fn keepOrReplace(allocator: std.mem.Allocator, original: []const u8, candidate: []const u8) ![]u8 {
    const trimmed = std.mem.trim(u8, candidate, &std.ascii.whitespace);
    return allocator.dupe(u8, if (trimmed.len == 0) original else trimmed);
}

pub const ModelList = struct {
    arena: std.heap.ArenaAllocator,
    names: []const []const u8,

    pub fn deinit(self: *ModelList) void {
        self.arena.deinit();
    }
};

pub const Server = enum { ollama, lm_studio };

/// Query the models a local server offers (`/api/tags` or `/v1/models`).
pub fn listModels(allocator: std.mem.Allocator, server: Server, base_url: []const u8) !ModelList {
    const path = switch (server) {
        .ollama => "/api/tags",
        .lm_studio => "/v1/models",
    };
    const response = try request(allocator, base_url, path, null);
    defer allocator.free(response);

    var result: ModelList = .{ .arena = std.heap.ArenaAllocator.init(allocator), .names = &.{} };
    errdefer result.arena.deinit();
    const arena = result.arena.allocator();

    var names: std.ArrayList([]const u8) = .empty;
    switch (server) {
        .ollama => {
            const Parsed = struct { models: []const struct { name: []const u8 } };
            const parsed = std.json.parseFromSliceLeaky(Parsed, arena, response, .{ .ignore_unknown_fields = true }) catch
                return Error.InvalidResponse;
            for (parsed.models) |m| try names.append(arena, m.name);
        },
        .lm_studio => {
            const Parsed = struct { data: []const struct { id: []const u8 } };
            const parsed = std.json.parseFromSliceLeaky(Parsed, arena, response, .{ .ignore_unknown_fields = true }) catch
                return Error.InvalidResponse;
            for (parsed.data) |m| try names.append(arena, m.id);
        },
    }
    result.names = try names.toOwnedSlice(arena);
    return result;
}

fn request(allocator: std.mem.Allocator, base_url: []const u8, path: []const u8, payload: ?[]const u8) ![]u8 {
    if (!ollama.isLoopbackEndpoint(base_url)) return Error.NonLocalEndpoint;

    const trimmed_base = std.mem.trimEnd(u8, base_url, "/");
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ trimmed_base, path });
    defer allocator.free(url);

    var client: std.http.Client = .{ .allocator = allocator, .io = utils.io() };
    defer client.deinit();

    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = if (payload != null) .POST else .GET,
        .payload = payload,
        .redirect_behavior = .not_allowed,
        .keep_alive = false,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .response_writer = &out.writer,
    });

    if (result.status != .ok) {
        utils.logError("LLM server {s} returned {d}", .{ url, @intFromEnum(result.status) });
        return Error.ServerError;
    }
    return out.toOwnedSlice();
}

test "mode parsing accepts tags and macOS display names" {
    try std.testing.expectEqual(Mode.grammar, Mode.parse("grammar"));
    try std.testing.expectEqual(Mode.technical, Mode.parse("Technical Writing"));
    try std.testing.expectEqual(Mode.concise, Mode.parse("concise & professional"));
    try std.testing.expectEqual(Mode.companion, Mode.parse("companion"));
    try std.testing.expectEqual(Mode.grammar, Mode.parse("nonsense"));
}

test "cleanup prompts forbid answering; companion prompt does not" {
    for (Mode.all) |mode| {
        const has_rule = std.mem.indexOf(u8, mode.systemPrompt(), "Input → Output (nothing else)") != null;
        try std.testing.expectEqual(mode != .companion, has_rule);
    }
}

test "ollama request body carries macOS parameters" {
    const allocator = std.testing.allocator;
    const stops = [_][]const u8{"###"};
    const body = try std.json.Stringify.valueAlloc(allocator, OllamaRequest{
        .model = "llama3.2:3b",
        .prompt = "hello \"world\"",
        .system = Mode.grammar.systemPrompt(),
        .options = .{ .temperature = 0.3, .top_p = 0.9, .top_k = 40, .repeat_penalty = 1.1, .num_ctx = 2048, .num_predict = 500 },
        .stop = &stops,
    }, .{ .emit_null_optional_fields = false });
    defer allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"num_ctx\":2048") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stop\":[\"###\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "hello \\\"world\\\"") != null);
}

test "empty LLM output keeps the raw transcript" {
    const allocator = std.testing.allocator;
    const kept = try keepOrReplace(allocator, "raw text", "  \n");
    defer allocator.free(kept);
    try std.testing.expectEqualStrings("raw text", kept);

    const replaced = try keepOrReplace(allocator, "raw text", " Clean text.\n");
    defer allocator.free(replaced);
    try std.testing.expectEqualStrings("Clean text.", replaced);
}

test "remote endpoints are refused before any request" {
    try std.testing.expectError(Error.NonLocalEndpoint, request(std.testing.allocator, "http://192.0.2.1:1234", "/v1/models", null));
}
