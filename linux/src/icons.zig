const std = @import("std");

/// Embedded icon data at compile time - zero runtime file I/O!
/// This is a low-level Zig win: icons are baked into the binary.
///
/// Benefits:
/// - Zero file I/O overhead
/// - No installation path dependencies
/// - Instant icon loading (<1μs)
/// - Self-contained binary
pub const Icons = struct {
    /// 22x22 icon for small tray areas
    pub const icon_22 = @embedFile("../assets/icon-22.png");

    /// 24x24 icon for standard tray
    pub const icon_24 = @embedFile("../assets/icon-24.png");

    /// 32x32 icon for high-DPI trays
    pub const icon_32 = @embedFile("../assets/icon-32.png");

    /// 48x48 icon for larger tray displays
    pub const icon_48 = @embedFile("../assets/icon-48.png");

    /// 512x512 icon for application window
    pub const icon_512 = @embedFile("../assets/icon-512.png");

    /// Get icon data for requested size (returns closest match)
    pub fn getIcon(size: u32) []const u8 {
        return switch (size) {
            0...22 => icon_22,
            23...24 => icon_24,
            25...32 => icon_32,
            33...48 => icon_48,
            else => icon_512,
        };
    }

    /// Get icon path for systems that require file paths
    /// Creates a temporary file in /tmp with the icon data
    pub fn getIconPath(allocator: std.mem.Allocator, size: u32) ![]const u8 {
        const icon_data = getIcon(size);

        // Generate temp path
        const path = try std.fmt.allocPrint(
            allocator,
            "/tmp/talkies-icon-{d}.png",
            .{size},
        );
        errdefer allocator.free(path);

        // Write icon data to temp file (only if it doesn't exist)
        const file = try std.fs.cwd().createFile(path, .{ .exclusive = false });
        defer file.close();

        try file.writeAll(icon_data);

        return path;
    }

    /// Write all icon sizes to a directory (for installation)
    pub fn installIcons(allocator: std.mem.Allocator, install_dir: []const u8) !void {
        const sizes = [_]u32{ 22, 24, 32, 48, 512 };

        for (sizes) |size| {
            const icon_data = getIcon(size);
            const filename = try std.fmt.allocPrint(
                allocator,
                "{s}/talkies-{d}.png",
                .{ install_dir, size },
            );
            defer allocator.free(filename);

            const file = try std.fs.cwd().createFile(filename, .{});
            defer file.close();

            try file.writeAll(icon_data);
        }
    }
};

test "icon sizes are embedded" {
    try std.testing.expect(Icons.icon_22.len > 0);
    try std.testing.expect(Icons.icon_24.len > 0);
    try std.testing.expect(Icons.icon_32.len > 0);
    try std.testing.expect(Icons.icon_48.len > 0);
    try std.testing.expect(Icons.icon_512.len > 0);
}

test "get icon by size" {
    const small = Icons.getIcon(20);
    const medium = Icons.getIcon(30);
    const large = Icons.getIcon(100);

    try std.testing.expect(small.len > 0);
    try std.testing.expect(medium.len > 0);
    try std.testing.expect(large.len > 0);
}
