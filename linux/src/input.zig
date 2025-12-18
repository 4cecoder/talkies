const std = @import("std");
const utils = @import("utils.zig");

/// Text insertion using xdotool
pub const TextInserter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TextInserter {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TextInserter) void {
        _ = self;
    }

    /// Simulate Ctrl+V paste
    pub fn paste(self: *TextInserter) !void {
        const argv = &[_][]const u8{ "xdotool", "key", "ctrl+v" };
        var child = std.process.Child.init(argv, self.allocator);
        _ = try child.spawnAndWait();
        utils.log("Pasted text", .{});
    }

    /// Type text directly (alternative to paste)
    pub fn typeText(self: *TextInserter, text: []const u8) !void {
        const argv = &[_][]const u8{ "xdotool", "type", "--", text };
        var child = std.process.Child.init(argv, self.allocator);
        _ = try child.spawnAndWait();
        utils.log("Typed text", .{});
    }
};

test "text inserter initialization" {
    const allocator = std.testing.allocator;
    const inserter = TextInserter.init(allocator);

    // Just verify initialization doesn't crash
    try std.testing.expect(inserter.allocator.vtable == allocator.vtable);
}
