const std = @import("std");
const utils = @import("core").utils;

/// Which post-processor runs on a transcript before it is inserted.
/// Mirrors the macOS app, where at most one LLM plugin is enabled at a time;
/// Linux additionally offers the on-device S1-mini cleanup model.
pub const EnhancerProvider = enum {
    none,
    s1_mini,
    ollama,
    lm_studio,

    pub fn displayName(self: EnhancerProvider) []const u8 {
        return switch (self) {
            .none => "Off",
            .s1_mini => "S1-mini (on-device)",
            .ollama => "Ollama",
            .lm_studio => "LM Studio",
        };
    }
};

/// Application configuration.
///
/// Stored as TOML at `$XDG_CONFIG_HOME/talkies/config.toml`. Section and key
/// names mirror the macOS `~/.talkies/config.json` schema (snake_case instead
/// of camelCase) so both platforms share the same settings and defaults.
///
/// Memory: every string field either points at a static default or at memory
/// owned by `arena`; nothing is freed individually. Replace strings only via
/// `setString` so the arena owns the new value.
pub const Config = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    // [general]
    push_to_talk_threshold: f64 = 0.15, // seconds a hotkey must be held to count as push-to-talk
    show_hud: bool = true,
    show_status_gui: bool = false,
    voice_assistant_mode: bool = false,
    insert_text_in_assistant_mode: bool = false,
    debug_mode: bool = false,

    // [audio]
    audio_device: []const u8 = "", // Empty string means use default device

    // [transcription]
    model: []const u8 = "base",
    language: []const u8 = "en",
    threads: u8 = 4,
    vocabulary_prompt: []const u8 = "",

    // [enhancement]
    enhancer: EnhancerProvider = .s1_mini,

    // [ollama]
    ollama_selected_model: []const u8 = "llama3.2:3b",
    ollama_host: []const u8 = "http://localhost:11434",
    ollama_enhancement_mode: []const u8 = "grammar",
    ollama_temperature: f64 = 0.3,
    ollama_top_p: f64 = 0.9,
    ollama_top_k: u32 = 40,
    ollama_repeat_penalty: f64 = 1.1,
    ollama_context_length: u32 = 2048,
    ollama_max_tokens: u32 = 500,
    ollama_custom_system_prompt: []const u8 = "",
    ollama_use_custom_prompt: bool = false,
    ollama_stop_sequences: []const u8 = "",

    // [lm_studio]
    lm_studio_selected_model: []const u8 = "",
    lm_studio_endpoint: []const u8 = "http://127.0.0.1:1234",
    lm_studio_enhancement_mode: []const u8 = "grammar",
    lm_studio_temperature: f64 = 0.3,
    lm_studio_top_p: f64 = 0.9,
    lm_studio_max_tokens: u32 = 4096,

    // [output]
    auto_paste: bool = true,
    paste_keybind: []const u8 = "ctrl+v",
    restore_clipboard: bool = true,

    // [platform]
    platform: []const u8 = "auto", // "auto", "x11", "wayland"

    // [yap] conversational refinement window (Linux-only, opt-in)
    yap_mode_enabled: bool = false,
    yap_llm_model: []const u8 = "granite3.3:2b",
    yap_ollama_url: []const u8 = "http://localhost:11434",
    yap_system_prompt: []const u8 = "You refine verbose voice transcriptions into clear, natural text. Keep the user's voice and intent. Don't capitalize every sentence - write naturally like you're texting or messaging. Be conversational, not formal.",

    // [vad]
    vad_enabled: bool = true,
    vad_mode: u8 = 2, // 0=quality, 1=low_bitrate, 2=aggressive, 3=very_aggressive

    /// Set when the file names `[enhancement] provider` explicitly, so the
    /// legacy `[cleanup] s1_mini_enabled` key cannot override it.
    enhancer_explicit: bool = false,

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        self.arena.deinit();
    }

    /// Replace a string field with an arena-owned copy of `value`.
    pub fn setString(self: *Config, comptime field: []const u8, value: []const u8) !void {
        @field(self, field) = try self.arena.allocator().dupe(u8, value);
    }

    /// Back-compat accessor for callers that only care whether S1-mini runs.
    pub fn s1CleanupEnabled(self: *const Config) bool {
        return self.enhancer == .s1_mini;
    }

    pub fn configPath(allocator: std.mem.Allocator) ![]u8 {
        const config_dir = try utils.getConfigDir(allocator);
        defer allocator.free(config_dir);
        return std.fmt.allocPrint(allocator, "{s}/config.toml", .{config_dir});
    }

    /// Create default configuration file if it doesn't exist
    pub fn createDefaultConfig(self: *Config) !void {
        const config_path = try configPath(self.allocator);
        defer self.allocator.free(config_path);

        if (std.Io.Dir.cwd().access(utils.io(), config_path, .{})) |_| {
            return;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }

        var defaults = Config.init(self.allocator);
        defer defaults.deinit();
        try defaults.save();
        utils.log("Created default config at: {s}", .{config_path});
    }

    /// Load configuration from disk, creating the default file if missing.
    pub fn load(self: *Config) !void {
        const file_io = utils.io();
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);
        try utils.ensureDir(config_dir);

        const config_path = try configPath(self.allocator);
        defer self.allocator.free(config_path);

        const file = std.Io.Dir.cwd().openFile(file_io, config_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                try self.createDefaultConfig();
                return;
            }
            return err;
        };
        defer file.close(file_io);

        const max_size = 1024 * 1024;
        const stat = try file.stat(file_io);
        const file_size = @min(stat.size, max_size);
        const content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(content);
        const bytes_read = try file.readStreaming(file_io, &.{content[0..]});

        try self.parseToml(content[0..bytes_read]);
        self.clampValues();

        utils.log("Config loaded from: {s}", .{config_path});
    }

    /// Parse TOML content and update config values
    fn parseToml(self: *Config, content: []const u8) !void {
        var current_section: []const u8 = "";
        var lines = std.mem.splitScalar(u8, content, '\n');

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                current_section = trimmed[1 .. trimmed.len - 1];
                continue;
            }

            if (std.mem.indexOfScalar(u8, trimmed, '=')) |eq_idx| {
                const key = std.mem.trim(u8, trimmed[0..eq_idx], &std.ascii.whitespace);
                const value_raw = std.mem.trim(u8, trimmed[eq_idx + 1 ..], &std.ascii.whitespace);
                try self.setConfigValue(current_section, key, value_raw);
            }
        }
    }

    fn setConfigValue(self: *Config, section: []const u8, key: []const u8, value_raw: []const u8) !void {
        // Legacy key from before the enhancer selector existed.
        if (std.mem.eql(u8, section, "cleanup") and std.mem.eql(u8, key, "s1_mini_enabled")) {
            if (!self.enhancer_explicit) {
                self.enhancer = if (try parseBoolValue(value_raw)) .s1_mini else .none;
            }
            return;
        }

        inline for (field_specs) |spec| {
            if (std.mem.eql(u8, section, spec.section) and std.mem.eql(u8, key, spec.key)) {
                try self.assignField(spec.field, value_raw);
                if (comptime std.mem.eql(u8, spec.field, "enhancer")) self.enhancer_explicit = true;
                return;
            }
        }
    }

    fn assignField(self: *Config, comptime field: []const u8, value_raw: []const u8) !void {
        const T = @TypeOf(@field(self, field));
        switch (@typeInfo(T)) {
            .bool => @field(self, field) = try parseBoolValue(value_raw),
            .int => @field(self, field) = try std.fmt.parseInt(T, value_raw, 10),
            .float => @field(self, field) = try std.fmt.parseFloat(T, value_raw),
            .@"enum" => {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                @field(self, field) = std.meta.stringToEnum(T, value) orelse return error.InvalidEnumValue;
            },
            .pointer => {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                try self.setString(field, value);
            },
            else => @compileError("unsupported config field type for " ++ field),
        }
    }

    /// Clamp numeric values to the ranges exposed by the macOS settings UI.
    fn clampValues(self: *Config) void {
        self.push_to_talk_threshold = std.math.clamp(self.push_to_talk_threshold, 0.05, 0.5);
        self.ollama_temperature = std.math.clamp(self.ollama_temperature, 0.0, 2.0);
        self.ollama_top_p = std.math.clamp(self.ollama_top_p, 0.0, 1.0);
        self.ollama_top_k = std.math.clamp(self.ollama_top_k, 0, 100);
        self.ollama_repeat_penalty = std.math.clamp(self.ollama_repeat_penalty, 0.0, 2.0);
        self.ollama_context_length = std.math.clamp(self.ollama_context_length, 512, 8192);
        self.ollama_max_tokens = std.math.clamp(self.ollama_max_tokens, 50, 2000);
        self.lm_studio_temperature = std.math.clamp(self.lm_studio_temperature, 0.0, 2.0);
        self.lm_studio_top_p = std.math.clamp(self.lm_studio_top_p, 0.0, 1.0);
        self.lm_studio_max_tokens = std.math.clamp(self.lm_studio_max_tokens, 50, 8192);
        if (self.vad_mode > 3) self.vad_mode = 2;
    }

    /// Serialize to TOML. Caller owns returned memory.
    pub fn toToml(self: *const Config, allocator: std.mem.Allocator) ![]u8 {
        var out: std.Io.Writer.Allocating = .init(allocator);
        errdefer out.deinit();
        const w = &out.writer;

        var current_section: []const u8 = "";
        inline for (field_specs) |spec| {
            if (!std.mem.eql(u8, current_section, spec.section)) {
                if (current_section.len != 0) try w.writeByte('\n');
                try w.print("[{s}]\n", .{spec.section});
                current_section = spec.section;
            }
            if (spec.comment.len != 0) try w.print("# {s}\n", .{spec.comment});
            try w.print("{s} = ", .{spec.key});

            const value = @field(self, spec.field);
            switch (@typeInfo(@TypeOf(value))) {
                .bool => try w.writeAll(if (value) "true" else "false"),
                .int => try w.print("{d}", .{value}),
                .float => try w.print("{d}", .{value}),
                .@"enum" => try w.print("\"{s}\"", .{@tagName(value)}),
                .pointer => {
                    const escaped = try escapeTomlString(allocator, value);
                    defer allocator.free(escaped);
                    try w.print("\"{s}\"", .{escaped});
                },
                else => @compileError("unsupported config field type"),
            }
            try w.writeByte('\n');
        }

        return out.toOwnedSlice();
    }

    /// Save configuration to disk
    pub fn save(self: *const Config) !void {
        const file_io = utils.io();
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);
        try utils.ensureDir(config_dir);

        const config_path = try configPath(self.allocator);
        defer self.allocator.free(config_path);

        const content = try self.toToml(self.allocator);
        defer self.allocator.free(content);

        const file = try std.Io.Dir.cwd().createFile(file_io, config_path, .{});
        defer file.close(file_io);
        try file.writeStreamingAll(file_io, content);
        utils.log("Config saved to: {s}", .{config_path});
    }

    /// Validate configuration values
    pub fn validate(self: *Config) !void {
        const valid_models = [_][]const u8{ "tiny", "base", "small", "medium", "large" };
        var valid_model = false;
        for (valid_models) |vm| {
            if (std.mem.eql(u8, self.model, vm)) {
                valid_model = true;
                break;
            }
        }
        if (!valid_model) {
            utils.log("Warning: Invalid model '{s}', using 'base'", .{self.model});
            self.model = "base";
        }

        if (self.threads < 1 or self.threads > 16) {
            utils.log("Warning: Invalid threads {d}, using 4", .{self.threads});
            self.threads = 4;
        }
        self.clampValues();
    }

    /// Print current configuration
    pub fn print(self: *Config) void {
        const content = self.toToml(self.allocator) catch |err| {
            std.debug.print("Failed to render configuration: {}\n", .{err});
            return;
        };
        defer self.allocator.free(content);
        std.debug.print("{s}", .{content});
    }

    /// Detect if running on Wayland
    pub fn detectPlatform() []const u8 {
        if (utils.getEnv("WAYLAND_DISPLAY")) |_| {
            return "wayland";
        }
        return "x11";
    }

    /// Get effective platform (resolve "auto")
    pub fn getEffectivePlatform(self: *const Config) []const u8 {
        if (std.mem.eql(u8, self.platform, "auto")) {
            return detectPlatform();
        }
        return self.platform;
    }
};

const FieldSpec = struct {
    section: []const u8,
    key: []const u8,
    field: []const u8,
    comment: []const u8 = "",
};

/// Serialization order and TOML location of every persisted field.
/// Entries must be grouped by section.
const field_specs = [_]FieldSpec{
    .{ .section = "general", .key = "push_to_talk_threshold", .field = "push_to_talk_threshold", .comment = "Hold the hotkey longer than this (seconds) for push-to-talk; a quicker tap toggles recording" },
    .{ .section = "general", .key = "show_hud", .field = "show_hud", .comment = "Floating dictation window with live waveform and pipeline status" },
    .{ .section = "general", .key = "show_status_gui", .field = "show_status_gui", .comment = "Developer status monitor with live logs" },
    .{ .section = "general", .key = "voice_assistant_mode", .field = "voice_assistant_mode", .comment = "Speak the result aloud (spd-say / espeak-ng) instead of inserting it" },
    .{ .section = "general", .key = "insert_text_in_assistant_mode", .field = "insert_text_in_assistant_mode" },
    .{ .section = "general", .key = "debug_mode", .field = "debug_mode" },

    .{ .section = "audio", .key = "device", .field = "audio_device", .comment = "PulseAudio source name (empty = default). List with: talkies audio-list" },

    .{ .section = "transcription", .key = "model", .field = "model", .comment = "tiny | base | small | medium | large" },
    .{ .section = "transcription", .key = "language", .field = "language" },
    .{ .section = "transcription", .key = "threads", .field = "threads" },
    .{ .section = "transcription", .key = "vocabulary_prompt", .field = "vocabulary_prompt", .comment = "Comma-separated names and uncommon words used as on-device Whisper hints (max 400 chars)" },

    .{ .section = "enhancement", .key = "provider", .field = "enhancer", .comment = "none | s1_mini | ollama | lm_studio" },

    .{ .section = "ollama", .key = "selected_model", .field = "ollama_selected_model" },
    .{ .section = "ollama", .key = "host", .field = "ollama_host", .comment = "Must be a loopback address; transcripts never leave this machine" },
    .{ .section = "ollama", .key = "enhancement_mode", .field = "ollama_enhancement_mode", .comment = "grammar | technical | concise | creative | companion" },
    .{ .section = "ollama", .key = "temperature", .field = "ollama_temperature" },
    .{ .section = "ollama", .key = "top_p", .field = "ollama_top_p" },
    .{ .section = "ollama", .key = "top_k", .field = "ollama_top_k" },
    .{ .section = "ollama", .key = "repeat_penalty", .field = "ollama_repeat_penalty" },
    .{ .section = "ollama", .key = "context_length", .field = "ollama_context_length" },
    .{ .section = "ollama", .key = "max_tokens", .field = "ollama_max_tokens" },
    .{ .section = "ollama", .key = "use_custom_prompt", .field = "ollama_use_custom_prompt" },
    .{ .section = "ollama", .key = "custom_system_prompt", .field = "ollama_custom_system_prompt" },
    .{ .section = "ollama", .key = "stop_sequences", .field = "ollama_stop_sequences", .comment = "Comma-separated" },

    .{ .section = "lm_studio", .key = "selected_model", .field = "lm_studio_selected_model", .comment = "Empty = first model the server reports" },
    .{ .section = "lm_studio", .key = "endpoint", .field = "lm_studio_endpoint", .comment = "Must be a loopback address; transcripts never leave this machine" },
    .{ .section = "lm_studio", .key = "enhancement_mode", .field = "lm_studio_enhancement_mode", .comment = "grammar | technical | concise | creative | companion" },
    .{ .section = "lm_studio", .key = "temperature", .field = "lm_studio_temperature" },
    .{ .section = "lm_studio", .key = "top_p", .field = "lm_studio_top_p" },
    .{ .section = "lm_studio", .key = "max_tokens", .field = "lm_studio_max_tokens" },

    .{ .section = "output", .key = "auto_paste", .field = "auto_paste" },
    .{ .section = "output", .key = "paste_keybind", .field = "paste_keybind", .comment = "ctrl+v | ctrl+shift+v (terminals) | shift+Insert" },
    .{ .section = "output", .key = "restore_clipboard", .field = "restore_clipboard", .comment = "Put your previous clipboard back after pasting" },

    .{ .section = "platform", .key = "mode", .field = "platform", .comment = "auto | x11 | wayland" },

    .{ .section = "yap", .key = "enabled", .field = "yap_mode_enabled", .comment = "Interactive LLM refinement window before pasting" },
    .{ .section = "yap", .key = "llm_model", .field = "yap_llm_model" },
    .{ .section = "yap", .key = "ollama_url", .field = "yap_ollama_url" },
    .{ .section = "yap", .key = "system_prompt", .field = "yap_system_prompt" },

    .{ .section = "vad", .key = "enabled", .field = "vad_enabled", .comment = "Trim silence before transcription" },
    .{ .section = "vad", .key = "mode", .field = "vad_mode", .comment = "0=quality, 1=low_bitrate, 2=aggressive, 3=very_aggressive" },
};

/// Parse a string value from TOML (removes quotes)
fn parseStringValue(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') {
        return allocator.dupe(u8, raw);
    }

    const encoded = raw[1 .. raw.len - 1];
    var decoded_len: usize = 0;
    var i: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '\\') {
            i += 1;
            if (i == encoded.len) return error.InvalidStringEscape;
            if (encoded[i] != '"' and encoded[i] != '\\' and encoded[i] != 'b' and encoded[i] != 't' and encoded[i] != 'n' and encoded[i] != 'f' and encoded[i] != 'r') {
                return error.InvalidStringEscape;
            }
        }
        decoded_len += 1;
    }

    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    i = 0;
    var out_index: usize = 0;
    while (i < encoded.len) : (i += 1) {
        if (encoded[i] == '\\') {
            i += 1;
            decoded[out_index] = switch (encoded[i]) {
                '"' => '"',
                '\\' => '\\',
                'b' => 0x08,
                't' => '\t',
                'n' => '\n',
                'f' => 0x0c,
                'r' => '\r',
                else => unreachable,
            };
        } else {
            decoded[out_index] = encoded[i];
        }
        out_index += 1;
    }
    return decoded;
}

fn escapeTomlString(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var escaped_len: usize = 0;
    for (value) |byte| {
        escaped_len += switch (byte) {
            '"', '\\', '\t', '\n', '\r', 0x08, 0x0c => 2,
            0...0x07, 0x0b, 0x0e...0x1f, 0x7f => return error.InvalidTomlStringValue,
            else => 1,
        };
    }

    const escaped = try allocator.alloc(u8, escaped_len);
    var index: usize = 0;
    for (value) |byte| {
        if (byte == '"' or byte == '\\') {
            escaped[index] = '\\';
            escaped[index + 1] = byte;
            index += 2;
        } else if (byte == '\t' or byte == '\n' or byte == '\r' or byte == 0x08 or byte == 0x0c) {
            escaped[index] = '\\';
            escaped[index + 1] = switch (byte) {
                '\t' => 't',
                '\n' => 'n',
                '\r' => 'r',
                0x08 => 'b',
                else => 'f',
            };
            index += 2;
        } else {
            escaped[index] = byte;
            index += 1;
        }
    }
    return escaped;
}

/// Parse a boolean value from TOML
fn parseBoolValue(raw: []const u8) !bool {
    if (std.mem.eql(u8, raw, "true")) {
        return true;
    } else if (std.mem.eql(u8, raw, "false")) {
        return false;
    }
    return error.InvalidBoolValue;
}

test "config initialization matches macOS defaults" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    try std.testing.expectEqualStrings("base", cfg.model);
    try std.testing.expectEqualStrings("en", cfg.language);
    try std.testing.expect(cfg.threads == 4);
    try std.testing.expect(cfg.auto_paste);
    try std.testing.expect(cfg.restore_clipboard);
    try std.testing.expectEqual(@as(f64, 0.15), cfg.push_to_talk_threshold);
    try std.testing.expectEqualStrings("llama3.2:3b", cfg.ollama_selected_model);
    try std.testing.expectEqualStrings("http://localhost:11434", cfg.ollama_host);
    try std.testing.expectEqual(@as(u32, 40), cfg.ollama_top_k);
    try std.testing.expectEqual(@as(u32, 2048), cfg.ollama_context_length);
    try std.testing.expectEqual(@as(u32, 500), cfg.ollama_max_tokens);
    try std.testing.expectEqualStrings("http://127.0.0.1:1234", cfg.lm_studio_endpoint);
    try std.testing.expectEqual(@as(u32, 4096), cfg.lm_studio_max_tokens);
    try std.testing.expect(cfg.s1CleanupEnabled());
}

test "parse string value" {
    const allocator = std.testing.allocator;
    const result1 = try parseStringValue(allocator, "\"hello\"");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("hello", result1);

    const result2 = try parseStringValue(allocator, "world");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("world", result2);
}

test "TOML string escaping round trips quotes, slashes, and line breaks" {
    const allocator = std.testing.allocator;
    const original = "Talkies says: \"hello\"\\world\nnext line";
    const escaped = try escapeTomlString(allocator, original);
    defer allocator.free(escaped);

    const quoted = try std.fmt.allocPrint(allocator, "\"{s}\"", .{escaped});
    defer allocator.free(quoted);
    const parsed = try parseStringValue(allocator, quoted);
    defer allocator.free(parsed);

    try std.testing.expectEqualStrings(original, parsed);
}

test "parse bool value" {
    try std.testing.expect(try parseBoolValue("true"));
    try std.testing.expect(!try parseBoolValue("false"));
    try std.testing.expectError(error.InvalidBoolValue, parseBoolValue("yes"));
}

test "parse toml content" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    const toml_content =
        \\[transcription]
        \\model = "small"
        \\language = "es"
        \\threads = 8
        \\vocabulary_prompt = "Talkies, WhisperKit, S1-mini"
        \\
        \\[output]
        \\auto_paste = false
        \\export_format = "srt"
        \\
        \\[ollama]
        \\temperature = 0.75
        \\top_k = 12
        \\enhancement_mode = "Technical Writing"
    ;

    try cfg.parseToml(toml_content);

    try std.testing.expectEqualStrings("small", cfg.model);
    try std.testing.expectEqualStrings("es", cfg.language);
    try std.testing.expect(cfg.threads == 8);
    try std.testing.expectEqualStrings("Talkies, WhisperKit, S1-mini", cfg.vocabulary_prompt);
    try std.testing.expect(!cfg.auto_paste);
    try std.testing.expectEqual(@as(f64, 0.75), cfg.ollama_temperature);
    try std.testing.expectEqual(@as(u32, 12), cfg.ollama_top_k);
    try std.testing.expectEqualStrings("Technical Writing", cfg.ollama_enhancement_mode);
}

test "legacy s1_mini_enabled maps to enhancer unless provider is explicit" {
    const allocator = std.testing.allocator;
    {
        var cfg = Config.init(allocator);
        defer cfg.deinit();
        try cfg.parseToml("[cleanup]\ns1_mini_enabled = false\n");
        try std.testing.expectEqual(EnhancerProvider.none, cfg.enhancer);
    }
    {
        var cfg = Config.init(allocator);
        defer cfg.deinit();
        try cfg.parseToml("[enhancement]\nprovider = \"ollama\"\n[cleanup]\ns1_mini_enabled = true\n");
        try std.testing.expectEqual(EnhancerProvider.ollama, cfg.enhancer);
    }
}

test "toToml round trips every field" {
    const allocator = std.testing.allocator;
    var original = Config.init(allocator);
    defer original.deinit();
    original.enhancer = .lm_studio;
    original.lm_studio_max_tokens = 1234;
    original.push_to_talk_threshold = 0.25;
    try original.setString("ollama_custom_system_prompt", "Line one\n\"quoted\"");

    const toml = try original.toToml(allocator);
    defer allocator.free(toml);

    var parsed = Config.init(allocator);
    defer parsed.deinit();
    try parsed.parseToml(toml);

    try std.testing.expectEqual(EnhancerProvider.lm_studio, parsed.enhancer);
    try std.testing.expectEqual(@as(u32, 1234), parsed.lm_studio_max_tokens);
    try std.testing.expectEqual(@as(f64, 0.25), parsed.push_to_talk_threshold);
    try std.testing.expectEqualStrings("Line one\n\"quoted\"", parsed.ollama_custom_system_prompt);
}

test "validate config" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    try cfg.setString("model", "invalid");
    try cfg.validate();
    try std.testing.expectEqualStrings("base", cfg.model);

    cfg.threads = 100;
    cfg.ollama_temperature = 9;
    try cfg.validate();
    try std.testing.expect(cfg.threads == 4);
    try std.testing.expectEqual(@as(f64, 2.0), cfg.ollama_temperature);
}
