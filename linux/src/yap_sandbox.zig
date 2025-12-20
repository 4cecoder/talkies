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
        io: std.Io,
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
            .ollama_client = ollama.Client.init(allocator, ollama_url, io),
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
                "Context:\n{s}\n\nRaw thoughts:\n{s}\n\nRefine these thoughts into a clear, cohesive message. Keep technical terms precise and business language natural. Remove filler words and redundancy while preserving key details:",
                .{ ctx, self.yapping },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "Raw thoughts:\n{s}\n\nRefine these into a clear, cohesive message. Keep technical terms precise and business language natural. Remove filler words and redundancy while preserving key details:",
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

    /// Request another refinement
    /// Re-refines using the full context + yapping (which may have been updated)
    pub fn refineAgain(self: *Sandbox, model: []const u8, _: ?[]const u8) ![]const u8 {
        // Build prompt using updated context and yapping
        // This ensures edits to the context field and new transcriptions are respected
        const prompt = if (self.initial_context) |ctx|
            try std.fmt.allocPrint(
                self.allocator,
                "Context:\n{s}\n\nRaw thoughts:\n{s}\n\nRefine these thoughts into a clear, cohesive message. Keep technical terms precise and business language natural. Remove filler words and redundancy while preserving key details:",
                .{ ctx, self.yapping },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "Raw thoughts:\n{s}\n\nRefine these into a clear, cohesive message. Keep technical terms precise and business language natural. Remove filler words and redundancy while preserving key details:",
                .{self.yapping},
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

    /// Get a specific revision by index (0-based)
    pub fn getRevision(self: *Sandbox, index: usize) ?[]const u8 {
        if (index >= self.revisions.items.len) return null;
        return self.revisions.items[index].text;
    }

    /// Get revision metadata (char count, timestamp)
    pub fn getRevisionInfo(self: *Sandbox, index: usize) ?struct { chars: usize, timestamp: i64 } {
        if (index >= self.revisions.items.len) return null;
        const rev = self.revisions.items[index];
        return .{ .chars = rev.char_count, .timestamp = rev.timestamp };
    }

    /// Format revision history for display
    pub fn formatHistory(self: *Sandbox) ![]const u8 {
        // Build format string parts
        var parts: std.ArrayList([]const u8) = .{};
        defer parts.deinit(self.allocator);

        try parts.append(self.allocator, "\n╔════════════════════════════════════════════════════════╗\n");
        try parts.append(self.allocator, "║            YAP SANDBOX - REVISION HISTORY              ║\n");
        try parts.append(self.allocator, "╚════════════════════════════════════════════════════════╝\n\n");

        // Show initial context if provided
        if (self.initial_context) |ctx| {
            try parts.append(self.allocator, "📋 INITIAL CONTEXT:\n");
            const ctx_str = try std.fmt.allocPrint(self.allocator, "{s}\n\n", .{ctx});
            try parts.append(self.allocator, ctx_str);
            try parts.append(self.allocator, "─────────────────────────────────────────────────────────\n\n");
        }

        // Show yapping
        const yapping_header = try std.fmt.allocPrint(self.allocator, "🗣️  YOUR YAPPING ({d} chars):\n{s}\n\n", .{ self.yapping.len, self.yapping });
        try parts.append(self.allocator, yapping_header);
        try parts.append(self.allocator, "─────────────────────────────────────────────────────────\n\n");

        // Show refinements
        if (self.revisions.items.len > 0) {
            try parts.append(self.allocator, "✨ REFINEMENTS:\n\n");
            for (self.revisions.items, 0..) |rev, i| {
                const rev_str = try std.fmt.allocPrint(self.allocator, "┌─ [v{d}] {d} chars ─┐\n{s}\n└──────────────────┘\n\n", .{ i + 1, rev.char_count, rev.text });
                try parts.append(self.allocator, rev_str);
            }
        } else {
            try parts.append(self.allocator, "⏳ No refinements yet\n\n");
        }

        // Join all parts
        return std.mem.join(self.allocator, "", parts.items);
    }
};
