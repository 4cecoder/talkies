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

    // Output settings
    auto_paste: bool = true,
    export_format: []const u8 = "txt",

    // Track if strings are owned (allocated)
    audio_device_owned: bool = false,
    model_owned: bool = false,
    language_owned: bool = false,
    export_format_owned: bool = false,

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
        if (self.export_format_owned) {
            self.allocator.free(self.export_format);
        }
    }

    /// Create default configuration file if it doesn't exist
    pub fn createDefaultConfig(self: *Config) !void {
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
        if (std.fs.cwd().access(config_path, .{})) |_| {
            // File exists, don't overwrite
            return;
        } else |_| {
            // File doesn't exist, create it
        }

        const file = try std.fs.cwd().createFile(config_path, .{});
        defer file.close();

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
            \\
            \\[output]
            \\auto_paste = true
            \\export_format = "txt"
            \\
        ;

        try file.writeAll(default_content);
        utils.log("Created default config at: {s}", .{config_path});
    }

    /// Load configuration from disk
    pub fn load(self: *Config) !void {
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
        const file = std.fs.cwd().openFile(config_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Create default config
                try self.createDefaultConfig();
                utils.log("Config file not found, created default at: {s}", .{config_path});
                return;
            }
            return err;
        };
        defer file.close();

        // Read file content
        const max_size = 1024 * 1024; // 1MB max
        const stat = try file.stat();
        const file_size = @min(stat.size, max_size);
        const content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(content);
        const bytes_read = try file.read(content[0..]);

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
                const value = try parseStringValue(value_raw);
                if (self.audio_device_owned) {
                    self.allocator.free(self.audio_device);
                }
                self.audio_device = try self.allocator.dupe(u8, value);
                self.audio_device_owned = true;
            }
        } else if (std.mem.eql(u8, section, "transcription")) {
            if (std.mem.eql(u8, key, "model")) {
                const value = try parseStringValue(value_raw);
                if (self.model_owned) {
                    self.allocator.free(self.model);
                }
                self.model = try self.allocator.dupe(u8, value);
                self.model_owned = true;
            } else if (std.mem.eql(u8, key, "language")) {
                const value = try parseStringValue(value_raw);
                if (self.language_owned) {
                    self.allocator.free(self.language);
                }
                self.language = try self.allocator.dupe(u8, value);
                self.language_owned = true;
            } else if (std.mem.eql(u8, key, "threads")) {
                self.threads = try parseIntValue(u8, value_raw);
            }
        } else if (std.mem.eql(u8, section, "output")) {
            if (std.mem.eql(u8, key, "auto_paste")) {
                self.auto_paste = try parseBoolValue(value_raw);
            } else if (std.mem.eql(u8, key, "export_format")) {
                const value = try parseStringValue(value_raw);
                if (self.export_format_owned) {
                    self.allocator.free(self.export_format);
                }
                self.export_format = try self.allocator.dupe(u8, value);
                self.export_format_owned = true;
            }
        }
    }

    /// Save configuration to disk
    pub fn save(self: *Config) !void {
        const config_dir = try utils.getConfigDir(self.allocator);
        defer self.allocator.free(config_dir);

        try utils.ensureDir(config_dir);

        const config_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/config.toml",
            .{config_dir},
        );
        defer self.allocator.free(config_path);

        // Create/overwrite file
        const file = try std.fs.cwd().createFile(config_path, .{});
        defer file.close();

        // Serialize to TOML format
        const content = try std.fmt.allocPrint(
            self.allocator,
            \\[transcription]
            \\model = "{s}"
            \\language = "{s}"
            \\threads = {d}
            \\
            \\[output]
            \\auto_paste = {s}
            \\export_format = "{s}"
            \\
        ,
            .{
                self.model,
                self.language,
                self.threads,
                if (self.auto_paste) "true" else "false",
                self.export_format,
            },
        );
        defer self.allocator.free(content);

        try file.writeAll(content);
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

        // Validate export format
        const valid_formats = [_][]const u8{ "txt", "srt", "vtt" };
        var valid_format = false;
        for (valid_formats) |vf| {
            if (std.mem.eql(u8, self.export_format, vf)) {
                valid_format = true;
                break;
            }
        }
        if (!valid_format) {
            utils.log("Warning: Invalid export_format '{s}', using 'txt'", .{self.export_format});
            if (self.export_format_owned) {
                self.allocator.free(self.export_format);
            }
            self.export_format = "txt";
            self.export_format_owned = false;
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
        std.debug.print("  Auto-paste: {}\n", .{self.auto_paste});
        std.debug.print("  Export format: {s}\n", .{self.export_format});
    }
};

/// Parse a string value from TOML (removes quotes)
fn parseStringValue(raw: []const u8) ![]const u8 {
    if (raw.len >= 2 and raw[0] == '"' and raw[raw.len - 1] == '"') {
        return raw[1 .. raw.len - 1];
    }
    return raw;
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
    try std.testing.expect(cfg.auto_paste == true);
}

test "parse string value" {
    const result1 = try parseStringValue("\"hello\"");
    try std.testing.expectEqualStrings("hello", result1);

    const result2 = try parseStringValue("world");
    try std.testing.expectEqualStrings("world", result2);
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
        \\
        \\[output]
        \\auto_paste = false
        \\export_format = "srt"
    ;

    try cfg.parseToml(toml_content);

    try std.testing.expectEqualStrings("small", cfg.model);
    try std.testing.expectEqualStrings("es", cfg.language);
    try std.testing.expect(cfg.threads == 8);
    try std.testing.expect(cfg.auto_paste == false);
    try std.testing.expectEqualStrings("srt", cfg.export_format);
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
