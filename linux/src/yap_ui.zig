const std = @import("std");
const daemon_ws = @import("daemon_ws.zig");
const yap_sandbox = @import("yap_sandbox.zig");

/// Terminal UI helpers for YAP mode (fallback when no WebSocket client)
/// Provides interactive prompts for accepting/refining/canceling YAP sessions

/// Display YAP refinement to user with stats
pub fn displayRefinement(
    writer: anytype,
    text: []const u8,
    revision_num: usize,
    original_chars: usize,
) !void {
    const char_count = text.len;
    const compression_ratio = if (original_chars > 0)
        @as(f32, @floatFromInt(char_count)) / @as(f32, @floatFromInt(original_chars))
    else
        1.0;

    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════╗\n");
    try writer.print("║  YAP REFINEMENT v{d}  ({d} chars, {d:.0}% of original)  ║\n", .{
        revision_num,
        char_count,
        compression_ratio * 100.0,
    });
    try writer.writeAll("╚════════════════════════════════════════════════════════╝\n");
    try writer.print("{s}\n", .{text});
    try writer.writeAll("────────────────────────────────────────────────────────\n");
}

/// Display YAP session summary (all revisions)
pub fn displaySessionSummary(
    writer: anytype,
    sandbox: *yap_sandbox.Sandbox,
) !void {
    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║              YAP SESSION - ALL REVISIONS               ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════╝\n\n");

    const original_len = sandbox.yapping.len;

    try writer.print("📝 Original yapping: {d} chars\n", .{original_len});
    try writer.print("✨ Refinements: {d}\n\n", .{sandbox.revisions.items.len});

    for (sandbox.revisions.items, 0..) |rev, i| {
        const ratio = @as(f32, @floatFromInt(rev.char_count)) / @as(f32, @floatFromInt(original_len));
        try writer.print("┌─ [v{d}] {d} chars ({d:.0}%) ─┐\n", .{ i + 1, rev.char_count, ratio * 100.0 });
        try writer.print("{s}\n", .{rev.text});
        try writer.writeAll("└────────────────────────────────┘\n\n");
    }
}

/// Prompt user for YAP command (terminal fallback)
/// Returns the chosen command or null if stdin is closed
pub fn promptYapCommand(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    writer: anytype,
) !?daemon_ws.YapCommand {
    try writer.writeAll("\n[YAP] (a)ccept / (r)efine / (c)ancel: ");

    // Read one line from stdin
    var buffer: [1024]u8 = undefined;
    const line = stdin.reader().readUntilDelimiter(&buffer, '\n') catch |err| {
        switch (err) {
            error.EndOfStream => return null,
            else => return err,
        }
    };

    // Trim whitespace
    const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

    // Parse command
    if (trimmed.len == 0) {
        return null;
    }

    const first_char = std.ascii.toLower(trimmed[0]);
    switch (first_char) {
        'a' => return .accept,
        'r' => return .refine,
        'c' => return .cancel,
        else => {
            try writer.print("Invalid command: '{s}'. Use (a)ccept, (r)efine, or (c)ancel.\n", .{trimmed});
            return promptYapCommand(allocator, stdin, writer);
        },
    }
}

/// Prompt user for refinement context (additional instructions)
/// Returns context string or null if user just presses Enter
pub fn promptRefineContext(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    writer: anytype,
) !?[]const u8 {
    try writer.writeAll("\n[YAP] Additional instructions (or Enter to skip): ");

    // Read one line from stdin
    var buffer: [1024]u8 = undefined;
    const line = stdin.reader().readUntilDelimiter(&buffer, '\n') catch |err| {
        switch (err) {
            error.EndOfStream => return null,
            else => return err,
        }
    };

    // Trim whitespace
    const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);

    if (trimmed.len == 0) {
        return null;
    }

    return try allocator.dupe(u8, trimmed);
}

/// Interactive YAP session (terminal-only mode)
/// This is a complete interactive loop for terminal-only usage
pub fn runInteractiveSession(
    allocator: std.mem.Allocator,
    sandbox: *yap_sandbox.Sandbox,
    model: []const u8,
) ![]const u8 {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    // Perform initial refinement
    try writer.writeAll("\n💬 Refining your message with LLM...\n");
    const initial_refined = try sandbox.refineInitial(model);
    const original_len = sandbox.yapping.len;

    // Display first refinement
    try displayRefinement(writer, initial_refined, 1, original_len);

    // Interactive loop
    while (true) {
        const command = try promptYapCommand(allocator, stdin, writer);

        if (command == null) {
            // stdin closed, default to accept
            return try allocator.dupe(u8, sandbox.getCurrentRefinement());
        }

        switch (command.?) {
            .accept => {
                try writer.writeAll("\n✅ Accepted! Pasting refined version...\n");
                return try allocator.dupe(u8, sandbox.getCurrentRefinement());
            },

            .refine => {
                const context = try promptRefineContext(allocator, stdin, writer);
                defer if (context) |ctx| allocator.free(ctx);

                if (context) |ctx| {
                    try writer.print("\n💬 Refining with context: \"{s}\"...\n", .{ctx});
                } else {
                    try writer.writeAll("\n💬 Refining again...\n");
                }

                const refined = try sandbox.refineAgain(
                    model,
                    context orelse "Refine the message further, making it more concise and clear.",
                );

                const revision_num = sandbox.getRevisionCount();
                try displayRefinement(writer, refined, revision_num, original_len);
            },

            .cancel => {
                try writer.writeAll("\n❌ Cancelled! Pasting original transcription...\n");
                return try allocator.dupe(u8, sandbox.yapping);
            },
        }
    }
}

/// Check if WebSocket clients are connected
/// Used to decide between WebSocket mode and terminal fallback
pub fn hasWebSocketClients(daemon_state: *daemon_ws.DaemonState) bool {
    // Check if the WebSocket server has any active connections
    // This is a simple heuristic - in production you'd query the server
    // For now, we'll assume if state is yap_refining, client is active
    return daemon_state.getState() == .yap_refining;
}

/// Wait for YAP command with timeout
/// Returns command or null on timeout
pub fn waitForYapCommand(
    daemon_state: *daemon_ws.DaemonState,
    timeout_ms: i64,
) ?daemon_ws.YapCommand {
    const start = std.time.milliTimestamp();

    while (true) {
        // Check for command
        if (daemon_state.getYapCommand()) |cmd| {
            return cmd;
        }

        // Check timeout
        const now = std.time.milliTimestamp();
        if (now - start >= timeout_ms) {
            return null;
        }

        // Sleep briefly to avoid busy-wait
        std.posix.nanosleep(0, 10 * std.time.ns_per_ms);
    }
}
