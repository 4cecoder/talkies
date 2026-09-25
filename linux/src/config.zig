const std = @import("std");
const utils = @import("utils.zig");

/// Application configuration
pub const Config = struct {
    allocator: std.mem.Allocator,

    // Audio settings
    audio_device: []const u8 = "", // Empty string means use default device

    // Transcription settings
    model: []const u8 = "base",
    language: []const u8 = "en",
    threads: u8 = 4,
    vocabulary_prompt: []const u8 = "",
    s1_cleanup_enabled: bool = true,

    // Output settings
    auto_paste: bool = true,
    paste_keybind: []const u8 = "ctrl+v", // Keybind for pasting (xdotool format)

    // Platform settings
    platform: []const u8 = "auto", // "auto", "x11", "wayland"

    // YAP mode settings (conversational LLM refinement)
    yap_mode_enabled: bool = true, // Enabled by default for testing
    yap_llm_model: []const u8 = "granite3.3:2b", // Ollama model to use
    yap_ollama_url: []const u8 = "http://localhost:11434",
    yap_system_prompt: []const u8 = "You refine verbose voice transcriptions into clear, natural text. Keep the user's voice and intent. Don't capitalize every sentence - write naturally like you're texting or messaging. Be conversational, not formal.",

    // Daemon GUI settings
    show_status_gui: bool = true, // Show daemon status monitor window

    // VAD (Voice Activity Detection) settings
    vad_enabled: bool = true, // Enable VAD to trim silence
    vad_mode: u8 = 2, // 0=quality, 1=low_bitrate, 2=aggressive, 3=very_aggressive

    // Track if strings are owned (allocated)
    audio_device_owned: bool = false,
    model_owned: bool = false,
    language_owned: bool = false,
    vocabulary_prompt_owned: bool = false,
    paste_keybind_owned: bool = false,
    platform_owned: bool = false,
    yap_llm_model_owned: bool = false,
    yap_ollama_url_owned: bool = false,
    yap_system_prompt_owned: bool = false,

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        if (self.audio_device_owned) {
            self.allocator.free(self.audio_device);
        }
        if (self.model_owned) {
            self.allocator.free(self.model);
        }
        if (self.language_owned) {
            self.allocator.free(self.language);
        }
        if (self.vocabulary_prompt_owned) {
            self.allocator.free(self.vocabulary_prompt);
        }
        if (self.paste_keybind_owned) {
            self.allocator.free(self.paste_keybind);
        }
        if (self.platform_owned) {
            self.allocator.free(self.platform);
        }
        if (self.yap_llm_model_owned) {
            self.allocator.free(self.yap_llm_model);
        }
        if (self.yap_ollama_url_owned) {
            self.allocator.free(self.yap_ollama_url);
        }
        if (self.yap_system_prompt_owned) {
            self.allocator.free(self.yap_system_prompt);
        }
    }

    /// Create default configuration file if it doesn't exist
    pub fn createDefaultConfig(self: *Config) !void {
        const file_io = utils.io();
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);

        try utils.ensureDir(config_dir);

        const config_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/config.toml",
            .{config_dir},
        );
        defer self.allocator.free(config_path);

        // Check if file already exists
        if (std.Io.Dir.cwd().access(file_io, config_path, .{})) |_| {
            // File exists, don't overwrite
            return;
        } else |_| {
            // File doesn't exist, create it
        }

        const file = try std.Io.Dir.cwd().createFile(file_io, config_path, .{});
        defer file.close(file_io);

        const default_content =
            \\[audio]
            \\# PulseAudio device name (empty = use default)
            \\# Find devices with: pactl list sources short
            \\# Example: alsa_input.usb-SunplusIT_Inc_Nisheng_M3_W20221116-02.mono-fallback
            \\device = ""
            \\
            \\[transcription]
            \\model = "base"
            \\language = "en"
            \\threads = 4
            \\# Comma-separated names and uncommon words used as on-device Whisper hints (max 400 chars)
            \\vocabulary_prompt = ""
            \\
            \\[cleanup]
            \\s1_mini_enabled = true
            \\
            \\[output]
            \\auto_paste = true
            \\# Paste keybind in xdotool format
            \\# Common options:
            \\#   "ctrl+v"        - Standard (Ctrl+V)
            \\#   "ctrl+shift+v"  - Terminal/Gentoo default (Ctrl+Shift+V)
            \\#   "shift+Insert"  - Alternative paste
            \\paste_keybind = "ctrl+v"
            \\
            \\[platform]
            \\# Platform mode: "auto" (detect), "x11" (daemon with Right Alt), "wayland" (compositor hotkey)
            \\mode = "auto"
            \\
            \\[yap]
            \\# YAP mode: Conversational LLM refinement before pasting
            \\# Helps yappers refine verbose speech into concise messages
            \\enabled = true
            \\llm_model = "granite"
            \\ollama_url = "http://localhost:11434"
            \\system_prompt = "You are a helpful assistant that refines verbose speech into concise, well-crafted messages. Maintain the user's intent and tone while being more succinct."
            \\
            \\[vad]
            \\# Voice Activity Detection: Trim silence before transcription
            \\# Improves speed by skipping silent portions
            \\enabled = true
            \\# Mode: 0=quality, 1=low_bitrate, 2=aggressive, 3=very_aggressive
            \\mode = 2
            \\
        ;

        try file.writeStreamingAll(file_io, default_content);
        utils.log("Created default config at: {s}", .{config_path});
    }

    /// Load configuration from disk
    pub fn load(self: *Config) !void {
        const file_io = utils.io();
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);

        try utils.ensureDir(config_dir);

        const config_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/config.toml",
            .{config_dir},
        );
        defer self.allocator.free(config_path);

        // Try to open the file
        const file = std.Io.Dir.cwd().openFile(file_io, config_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Create default config
                try self.createDefaultConfig();
                utils.log("Config file not found, created default at: {s}", .{config_path});
                return;
            }
            return err;
        };
        defer file.close(file_io);

        // Read file content
        const max_size = 1024 * 1024; // 1MB max
        const stat = try file.stat(file_io);
        const file_size = @min(stat.size, max_size);
        const content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(content);
        const bytes_read = try file.readStreaming(file_io, &.{content[0..]});

        // Parse TOML content
        try self.parseToml(content[0..bytes_read]);

        utils.log("Config loaded from: {s}", .{config_path});
    }

    /// Parse TOML content and update config values
    fn parseToml(self: *Config, content: []const u8) !void {
        var current_section: []const u8 = "";
        var lines = std.mem.splitScalar(u8, content, '\n');

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

            // Skip empty lines and comments
            if (trimmed.len == 0 or trimmed[0] == '#') {
                continue;
            }

            // Section header
            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                current_section = trimmed[1 .. trimmed.len - 1];
                continue;
            }

            // Key-value pair
            if (std.mem.indexOf(u8, trimmed, "=")) |eq_idx| {
                const key = std.mem.trim(u8, trimmed[0..eq_idx], &std.ascii.whitespace);
                const value_raw = std.mem.trim(u8, trimmed[eq_idx + 1 ..], &std.ascii.whitespace);

                try self.setConfigValue(current_section, key, value_raw);
            }
        }
    }

    /// Set a configuration value based on section and key
    fn setConfigValue(self: *Config, section: []const u8, key: []const u8, value_raw: []const u8) !void {
        if (std.mem.eql(u8, section, "audio")) {
            if (std.mem.eql(u8, key, "device")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.audio_device_owned) {
                    self.allocator.free(self.audio_device);
                }
                self.audio_device = try self.allocator.dupe(u8, value);
                self.audio_device_owned = true;
            }
        } else if (std.mem.eql(u8, section, "transcription")) {
            if (std.mem.eql(u8, key, "model")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.model_owned) {
                    self.allocator.free(self.model);
                }
                self.model = try self.allocator.dupe(u8, value);
                self.model_owned = true;
            } else if (std.mem.eql(u8, key, "language")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.language_owned) {
                    self.allocator.free(self.language);
                }
                self.language = try self.allocator.dupe(u8, value);
                self.language_owned = true;
            } else if (std.mem.eql(u8, key, "threads")) {
                self.threads = try parseIntValue(u8, value_raw);
            } else if (std.mem.eql(u8, key, "vocabulary_prompt")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.vocabulary_prompt_owned) self.allocator.free(self.vocabulary_prompt);
                self.vocabulary_prompt = try self.allocator.dupe(u8, value);
                self.vocabulary_prompt_owned = true;
            }
        } else if (std.mem.eql(u8, section, "output")) {
            if (std.mem.eql(u8, key, "auto_paste")) {
                self.auto_paste = try parseBoolValue(value_raw);
            } else if (std.mem.eql(u8, key, "paste_keybind")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.paste_keybind_owned) {
                    self.allocator.free(self.paste_keybind);
                }
                self.paste_keybind = try self.allocator.dupe(u8, value);
                self.paste_keybind_owned = true;
            }
        } else if (std.mem.eql(u8, section, "cleanup")) {
            if (std.mem.eql(u8, key, "s1_mini_enabled")) {
                self.s1_cleanup_enabled = try parseBoolValue(value_raw);
            }
        } else if (std.mem.eql(u8, section, "platform")) {
            if (std.mem.eql(u8, key, "mode")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.platform_owned) {
                    self.allocator.free(self.platform);
                }
                self.platform = try self.allocator.dupe(u8, value);
                self.platform_owned = true;
            }
        } else if (std.mem.eql(u8, section, "yap")) {
            if (std.mem.eql(u8, key, "enabled")) {
                self.yap_mode_enabled = try parseBoolValue(value_raw);
            } else if (std.mem.eql(u8, key, "llm_model")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.yap_llm_model_owned) {
                    self.allocator.free(self.yap_llm_model);
                }
                self.yap_llm_model = try self.allocator.dupe(u8, value);
                self.yap_llm_model_owned = true;
            } else if (std.mem.eql(u8, key, "ollama_url")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.yap_ollama_url_owned) {
                    self.allocator.free(self.yap_ollama_url);
                }
                self.yap_ollama_url = try self.allocator.dupe(u8, value);
                self.yap_ollama_url_owned = true;
            } else if (std.mem.eql(u8, key, "system_prompt")) {
                const value = try parseStringValue(self.allocator, value_raw);
                defer self.allocator.free(value);
                if (self.yap_system_prompt_owned) {
                    self.allocator.free(self.yap_system_prompt);
                }
                self.yap_system_prompt = try self.allocator.dupe(u8, value);
                self.yap_system_prompt_owned = true;
            }
        } else if (std.mem.eql(u8, section, "vad")) {
            if (std.mem.eql(u8, key, "enabled")) {
                self.vad_enabled = try parseBoolValue(value_raw);
            } else if (std.mem.eql(u8, key, "mode")) {
                self.vad_mode = try parseIntValue(u8, value_raw);
            }
        }
    }

    /// Save configuration to disk
    pub fn save(self: *Config) !void {
        const file_io = utils.io();
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);

        try utils.ensureDir(config_dir);

        const config_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/config.toml",
            .{config_dir},
        );
        defer self.allocator.free(config_path);

        const audio_device = try escapeTomlString(self.allocator, self.audio_device);
        defer self.allocator.free(audio_device);
        const model = try escapeTomlString(self.allocator, self.model);
        defer self.allocator.free(model);
        const language = try escapeTomlString(self.allocator, self.language);
        defer self.allocator.free(language);
        const vocabulary_prompt = try escapeTomlString(self.allocator, self.vocabulary_prompt);
        defer self.allocator.free(vocabulary_prompt);
        const paste_keybind = try escapeTomlString(self.allocator, self.paste_keybind);
        defer self.allocator.free(paste_keybind);
        const platform = try escapeTomlString(self.allocator, self.platform);
        defer self.allocator.free(platform);
        const yap_llm_model = try escapeTomlString(self.allocator, self.yap_llm_model);
        defer self.allocator.free(yap_llm_model);
        const yap_ollama_url = try escapeTomlString(self.allocator, self.yap_ollama_url);
        defer self.allocator.free(yap_ollama_url);
        const yap_system_prompt = try escapeTomlString(self.allocator, self.yap_system_prompt);
        defer self.allocator.free(yap_system_prompt);

        // Create/overwrite file
        const file = try std.Io.Dir.cwd().createFile(file_io, config_path, .{});
        defer file.close(file_io);

        // Serialize to TOML format
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\[audio]
            \\device = "{s}"
            \\
            \\[transcription]
            \\model = "{s}"
            \\language = "{s}"
            \\threads = {d}
            \\vocabulary_prompt = "{s}"
            \\
            \\[cleanup]
            \\s1_mini_enabled = {s}
            \\
            \\[output]
            \\auto_paste = {s}
            \\paste_keybind = "{s}"
            \\
            \\[platform]
            \\mode = "{s}"
            \\
            \\[yap]
            \\enabled = {s}
            \\llm_model = "{s}"
            \\ollama_url = "{s}"
            \\system_prompt = "{s}"
            \\
            \\[vad]
            \\enabled = {s}
            \\mode = {d}
            \\
        ,
            .{
                audio_device,
                model,
                language,
                self.threads,
                vocabulary_prompt,
                if (self.s1_cleanup_enabled) "true" else "false",
                if (self.auto_paste) "true" else "false",
                paste_keybind,
                platform,
                if (self.yap_mode_enabled) "true" else "false",
                yap_llm_model,
                yap_ollama_url,
                yap_system_prompt,
                if (self.vad_enabled) "true" else "false",
                self.vad_mode,
            },
        );
        defer self.allocator.free(content);

        try file.writeStreamingAll(file_io, content);
        utils.log("Config saved to: {s}", .{config_path});
    }

    /// Validate configuration values
    pub fn validate(self: *Config) !void {
        // Validate model
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
            if (self.model_owned) {
                self.allocator.free(self.model);
            }
            self.model = "base";
            self.model_owned = false;
        }

        // Validate threads (1-16)
        if (self.threads < 1 or self.threads > 16) {
            utils.log("Warning: Invalid threads {d}, using 4", .{self.threads});
            self.threads = 4;
        }
    }

    /// Print current configuration
    pub fn print(self: *Config) void {
        std.debug.print("Configuration:\n", .{});
        std.debug.print("  Audio device: {s}\n", .{if (self.audio_device.len > 0) self.audio_device else "(default)"});
        std.debug.print("  Model: {s}\n", .{self.model});
        std.debug.print("  Language: {s}\n", .{self.language});
        std.debug.print("  Threads: {d}\n", .{self.threads});
        std.debug.print("  Local recognition hints: {s}\n", .{if (self.vocabulary_prompt.len > 0) self.vocabulary_prompt else "(none)"});
        std.debug.print("  S1-mini cleanup: {}\n", .{self.s1_cleanup_enabled});
        std.debug.print("  Auto-paste: {}\n", .{self.auto_paste});
        std.debug.print("  Platform mode: {s}\n", .{self.platform});
    }

    /// Detect if running on Wayland
    pub fn detectPlatform() []const u8 {
        if (utils.getEnv("WAYLAND_DISPLAY")) |_| {
            return "wayland";
        }
        return "x11";
    }

    /// Get effective platform (resolve "auto")
    pub fn getEffectivePlatform(self: *Config) []const u8 {
        if (std.mem.eql(u8, self.platform, "auto")) {
            return detectPlatform();
        }
        return self.platform;
    }
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

/// Parse an integer value from TOML
fn parseIntValue(comptime T: type, raw: []const u8) !T {
    return std.fmt.parseInt(T, raw, 10);
}

test "config initialization" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    try std.testing.expectEqualStrings("base", cfg.model);
    try std.testing.expectEqualStrings("en", cfg.language);
    try std.testing.expect(cfg.threads == 4);
    try std.testing.expectEqualStrings("", cfg.vocabulary_prompt);
    try std.testing.expect(cfg.auto_paste == true);
    try std.testing.expect(cfg.s1_cleanup_enabled);
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
    const result1 = try parseBoolValue("true");
    try std.testing.expect(result1 == true);

    const result2 = try parseBoolValue("false");
    try std.testing.expect(result2 == false);
}

test "parse int value" {
    const result1 = try parseIntValue(u8, "42");
    try std.testing.expect(result1 == 42);

    const result2 = try parseIntValue(u8, "8");
    try std.testing.expect(result2 == 8);
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
        \\[cleanup]
        \\s1_mini_enabled = false
        \\
        \\[output]
        \\auto_paste = false
        \\export_format = "srt"
    ;

    try cfg.parseToml(toml_content);

    try std.testing.expectEqualStrings("small", cfg.model);
    try std.testing.expectEqualStrings("es", cfg.language);
    try std.testing.expect(cfg.threads == 8);
    try std.testing.expectEqualStrings("Talkies, WhisperKit, S1-mini", cfg.vocabulary_prompt);
    try std.testing.expect(!cfg.s1_cleanup_enabled);
    try std.testing.expect(cfg.auto_paste == false);
}

test "validate config" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    // Test invalid model
    cfg.model = try allocator.dupe(u8, "invalid");
    cfg.model_owned = true;
    try cfg.validate();
    try std.testing.expectEqualStrings("base", cfg.model);

    // Test invalid threads
    cfg.threads = 100;
    try cfg.validate();
    try std.testing.expect(cfg.threads == 4);

    // Test valid values
    cfg.model = try allocator.dupe(u8, "tiny");
    cfg.model_owned = true;
    cfg.threads = 2;
    try cfg.validate();
    try std.testing.expectEqualStrings("tiny", cfg.model);
    try std.testing.expect(cfg.threads == 2);
}
