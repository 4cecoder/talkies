const std = @import("std");
const ollama = @import("ollama.zig");

/// YAP Sandbox: Interactive refinement session  
/// Workflow: User provides initial context → records yapping → LLM refines → final message
pub const Sandbox = struct {
    allocator: std.mem.Allocator,
    ollama_client: ollama.Client,

    // Initial context (pasted info, reference material, etc.)
    initial_context: ?[]const u8,

    // User's yapping (verbose voice transcription)
    yapping: []const u8,

    // Refinement history (newest last)
    revisions: std.ArrayListUnmanaged(Revision),

    // Conversation context for LLM
    conversation: std.ArrayListUnmanaged(Message),

    pub const Revision = struct {
        text: []const u8,
        timestamp: i64,
        char_count: usize,

        pub fn deinit(self: *Revision, allocator: std.mem.Allocator) void {
            allocator.free(self.text);
        }
    };

    pub const Message = struct {
        role: Role,
        content: []const u8,

        pub const Role = enum {
            system,
            user,
            assistant,
        };

        pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
            allocator.free(self.content);
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        yapping_text: []const u8,
        context: ?[]const u8,
        ollama_url: []const u8,
        system_prompt: []const u8,
    ) !Sandbox {
        const revisions: std.ArrayListUnmanaged(Revision) = .{};
        var conversation: std.ArrayListUnmanaged(Message) = .{};

        // Add system prompt to conversation
        const system_msg = Message{
            .role = .system,
            .content = try allocator.dupe(u8, system_prompt),
        };
        try conversation.append(allocator, system_msg);

        const yapping_copy = try allocator.dupe(u8, yapping_text);
        const context_copy = if (context) |ctx| try allocator.dupe(u8, ctx) else null;

        return .{
            .allocator = allocator,
            .ollama_client = ollama.Client.init(allocator, ollama_url),
            .initial_context = context_copy,
            .yapping = yapping_copy,
            .revisions = revisions,
            .conversation = conversation,
        };
    }

    pub fn deinit(self: *Sandbox) void {
        // Free all revisions
        for (self.revisions.items) |*rev| {
            rev.deinit(self.allocator);
        }
        self.revisions.deinit(self.allocator);

        // Free conversation
        for (self.conversation.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.conversation.deinit(self.allocator);

        // Free yapping and context
        self.allocator.free(self.yapping);
        if (self.initial_context) |ctx| {
            self.allocator.free(ctx);
        }

        self.ollama_client.deinit();
    }

    /// Get the current (latest) refinement
    pub fn getCurrentRefinement(self: *Sandbox) []const u8 {
        if (self.revisions.items.len > 0) {
            return self.revisions.items[self.revisions.items.len - 1].text;
        }
        // No refinements yet, return yapping
        return self.yapping;
    }

    /// Request initial refinement from LLM
    /// Combines initial context + yapping into a refined message
    pub fn refineInitial(self: *Sandbox, model: []const u8) ![]const u8 {
        // Build prompt with context + yapping
        const prompt = if (self.initial_context) |ctx|
            try std.fmt.allocPrint(
                self.allocator,
                "Initial Context:\n{s}\n\nMy Thoughts (verbose):\n{s}\n\nCreate a concise, well-structured message combining the context and my thoughts:",
                .{ ctx, self.yapping },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "My Thoughts (verbose):\n{s}\n\nRefine this into a concise, clear message:",
                .{self.yapping},
            );
        defer self.allocator.free(prompt);

        // Add user message to conversation
        const user_msg = Message{
            .role = .user,
            .content = try self.allocator.dupe(u8, prompt),
        };
        try self.conversation.append(self.allocator, user_msg);

        // Get refinement from LLM
        const system_prompt = self.conversation.items[0].content;
        const refined = try self.ollama_client.generate(model, prompt, system_prompt);

        // Add assistant response to conversation
        const assistant_msg = Message{
            .role = .assistant,
            .content = try self.allocator.dupe(u8, refined),
        };
        try self.conversation.append(self.allocator, assistant_msg);

        // Store as new revision
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);
        const revision = Revision{
            .text = try self.allocator.dupe(u8, refined),
            .timestamp = now,
            .char_count = refined.len,
        };
        try self.revisions.append(self.allocator, revision);

        return refined;
    }

    /// Request another refinement with additional context
    pub fn refineAgain(self: *Sandbox, model: []const u8, additional_context: []const u8) ![]const u8 {
        const current = self.getCurrentRefinement();

        // Build prompt with context
        const prompt = try std.fmt.allocPrint(
            self.allocator,
            "Current message:\n{s}\n\nAdditional instructions: {s}\n\nProvide the refined version:",
            .{ current, additional_context },
        );
        defer self.allocator.free(prompt);

        // Add user message
        const user_msg = Message{
            .role = .user,
            .content = try self.allocator.dupe(u8, prompt),
        };
        try self.conversation.append(self.allocator, user_msg);

        // Get refinement
        const system_prompt = self.conversation.items[0].content;
        const refined = try self.ollama_client.generate(model, prompt, system_prompt);

        // Add assistant response
        const assistant_msg = Message{
            .role = .assistant,
            .content = try self.allocator.dupe(u8, refined),
        };
        try self.conversation.append(self.allocator, assistant_msg);

        // Store revision
        const ts = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const now = @as(i64, ts.sec);
        const revision = Revision{
            .text = try self.allocator.dupe(u8, refined),
            .timestamp = now,
            .char_count = refined.len,
        };
        try self.revisions.append(self.allocator, revision);

        return refined;
    }

    /// Get revision count
    pub fn getRevisionCount(self: *Sandbox) usize {
        return self.revisions.items.len;
    }

    /// Format revision history for display
    pub fn formatHistory(self: *Sandbox) ![]const u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        errdefer buffer.deinit();

        const writer = buffer.writer();

        try writer.writeAll("\n╔════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║            YAP SANDBOX - REVISION HISTORY              ║\n");
        try writer.writeAll("╚════════════════════════════════════════════════════════╝\n\n");

        // Show initial context if provided
        if (self.initial_context) |ctx| {
            try writer.writeAll("📋 INITIAL CONTEXT:\n");
            try writer.print("{s}\n\n", .{ctx});
            try writer.writeAll("─────────────────────────────────────────────────────────\n\n");
        }

        // Show yapping
        try writer.print("🗣️  YOUR YAPPING ({d} chars):\n", .{self.yapping.len});
        try writer.print("{s}\n\n", .{self.yapping});
        try writer.writeAll("─────────────────────────────────────────────────────────\n\n");

        // Show refinements
        if (self.revisions.items.len > 0) {
            try writer.writeAll("✨ REFINEMENTS:\n\n");
            for (self.revisions.items, 0..) |rev, i| {
                try writer.print("┌─ [v{d}] {d} chars ─┐\n", .{ i + 1, rev.char_count });
                try writer.print("{s}\n", .{rev.text});
                try writer.writeAll("└──────────────────┘\n\n");
            }
        } else {
            try writer.writeAll("⏳ No refinements yet\n\n");
        }

        return buffer.toOwnedSlice();
    }
};
