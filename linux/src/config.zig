const std = @import("std");
const utils = @import("utils.zig");

/// Application configuration
pub const Config = struct {
    allocator: std.mem.Allocator,

    // Transcription settings
    model: []const u8 = "base",
    language: []const u8 = "en",
    threads: u8 = 4,

    // Output settings
    auto_paste: bool = true,
    export_format: []const u8 = "txt",

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        _ = self;
        // TODO: Free any dynamically allocated strings
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

        // TODO: Parse TOML config file
        // TODO: Update self with loaded values
        utils.log("Config loaded from: {s}", .{config_path});
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

        // TODO: Serialize config to TOML
        // TODO: Write to file
        utils.log("Config saved to: {s}", .{config_path});
    }

    /// Print current configuration
    pub fn print(self: *Config) void {
        std.debug.print("Configuration:\n", .{});
        std.debug.print("  Model: {s}\n", .{self.model});
        std.debug.print("  Language: {s}\n", .{self.language});
        std.debug.print("  Threads: {d}\n", .{self.threads});
        std.debug.print("  Auto-paste: {}\n", .{self.auto_paste});
        std.debug.print("  Export format: {s}\n", .{self.export_format});
    }
};

test "config initialization" {
    const allocator = std.testing.allocator;
    var cfg = Config.init(allocator);
    defer cfg.deinit();

    try std.testing.expectEqualStrings("base", cfg.model);
    try std.testing.expectEqualStrings("en", cfg.language);
    try std.testing.expect(cfg.threads == 4);
    try std.testing.expect(cfg.auto_paste == true);
}
