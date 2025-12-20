const std = @import("std");
const websocket = @import("websocket.zig");

/// WebSocket message types for Talkies daemon
pub const MessageType = enum {
    // Commands (client → server)
    start_recording,
    stop_recording,
    get_state,
    yap_accept,     // Accept current refinement and paste
    yap_refine,     // Request another refinement (with optional new context)
    yap_cancel,     // Cancel YAP mode, paste original

    // Events (server → client)
    state_changed,
    audio_level,
    transcription_complete,
    yap_refined,    // New refinement ready
    @"error",
};

/// Application state
pub const State = enum {
    idle,
    recording,
    processing,
    yap_refining, // Interactive refinement mode

    pub fn toString(self: State) []const u8 {
        return switch (self) {
            .idle => "idle",
            .recording => "recording",
            .processing => "processing",
            .yap_refining => "yap_refining",
        };
    }
};

/// YAP command types for interactive refinement
pub const YapCommand = enum {
    accept,  // Accept current refinement and paste
    refine,  // Request another refinement
    cancel,  // Cancel YAP mode, paste original

    pub fn toString(self: YapCommand) []const u8 {
        return switch (self) {
            .accept => "accept",
            .refine => "refine",
            .cancel => "cancel",
        };
    }
};

/// Daemon state manager with WebSocket broadcasting
pub const DaemonState = struct {
    allocator: std.mem.Allocator,
    ws_server: *websocket.Server,
    current_state: State,
    mutex: std.Thread.Mutex,

    // YAP command queue (for interactive refinement)
    yap_command: ?YapCommand,
    yap_refine_context: ?[]const u8,  // Optional context for refine command
    yap_mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, ws_server: *websocket.Server) DaemonState {
        return .{
            .allocator = allocator,
            .ws_server = ws_server,
            .current_state = .idle,
            .mutex = .{},
            .yap_command = null,
            .yap_refine_context = null,
            .yap_mutex = .{},
        };
    }

    /// Set state and broadcast to all connected clients
    pub fn setState(self: *DaemonState, new_state: State) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.current_state == new_state) return; // No change

        self.current_state = new_state;
        std.debug.print("State changed: {s}\n", .{new_state.toString()});

        // Broadcast state change
        const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
        const timestamp_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"state_changed\",\"data\":{{\"state\":\"{s}\",\"timestamp\":{d}}}}}",
            .{ new_state.toString(), timestamp_ms },
        );
        defer self.allocator.free(message);

        try self.ws_server.broadcast(message);
    }

    /// Broadcast audio level to all clients
    pub fn broadcastAudioLevel(self: *DaemonState, level: f32) !void {
        const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
        const timestamp_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"audio_level\",\"data\":{{\"level\":{d:.2},\"timestamp\":{d}}}}}",
            .{ level, timestamp_ms },
        );
        defer self.allocator.free(message);

        try self.ws_server.broadcast(message);
    }

    /// Broadcast waveform data (array of levels)
    pub fn broadcastWaveform(self: *DaemonState, levels: []const f32) !void {
        // Build JSON array
        var json: std.ArrayList(u8) = .{};
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "{\"type\":\"waveform_update\",\"data\":{\"levels\":[");

        for (levels, 0..) |level, i| {
            if (i > 0) try json.append(self.allocator, ',');
            try json.writer().print("{d:.2}", .{level});
        }

        const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
        const timestamp_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
        try json.writer().print("],\"timestamp\":{d}}}}}", .{timestamp_ms});

        try self.ws_server.broadcast(json.items);
    }

    /// Broadcast transcription completion
    pub fn broadcastTranscription(self: *DaemonState, text: []const u8, duration_ms: i64) !void {
        // Escape JSON string
        var escaped: std.ArrayList(u8) = .{};
        defer escaped.deinit(self.allocator);

        for (text) |c| {
            switch (c) {
                '"' => try escaped.appendSlice(self.allocator, "\\\""),
                '\\' => try escaped.appendSlice(self.allocator, "\\\\"),
                '\n' => try escaped.appendSlice(self.allocator, "\\n"),
                '\r' => try escaped.appendSlice(self.allocator, "\\r"),
                '\t' => try escaped.appendSlice(self.allocator, "\\t"),
                else => try escaped.append(self.allocator, c),
            }
        }

        const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
        const timestamp_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"transcription_complete\",\"data\":{{\"text\":\"{s}\",\"duration_ms\":{d},\"timestamp\":{d}}}}}",
            .{ escaped.items, duration_ms, timestamp_ms },
        );
        defer self.allocator.free(message);

        try self.ws_server.broadcast(message);
    }

    /// Broadcast error
    pub fn broadcastError(self: *DaemonState, error_message: []const u8, code: []const u8) !void {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"error\",\"data\":{{\"message\":\"{s}\",\"code\":\"{s}\"}}}}",
            .{ error_message, code },
        );
        defer self.allocator.free(message);

        try self.ws_server.broadcast(message);
    }

    /// Broadcast YAP refinement event
    pub fn broadcastYapRefined(
        self: *DaemonState,
        text: []const u8,
        revision_num: i32,
        original_chars: usize,
    ) !void {
        // Escape JSON string
        var escaped: std.ArrayList(u8) = .{};
        defer escaped.deinit(self.allocator);

        for (text) |c| {
            switch (c) {
                '"' => try escaped.appendSlice(self.allocator, "\\\""),
                '\\' => try escaped.appendSlice(self.allocator, "\\\\"),
                '\n' => try escaped.appendSlice(self.allocator, "\\n"),
                '\r' => try escaped.appendSlice(self.allocator, "\\r"),
                '\t' => try escaped.appendSlice(self.allocator, "\\t"),
                else => try escaped.append(self.allocator, c),
            }
        }

        // Calculate compression ratio
        const char_count = text.len;
        const compression_ratio = if (original_chars > 0)
            @as(f32, @floatFromInt(char_count)) / @as(f32, @floatFromInt(original_chars))
        else
            1.0;

        const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
        const timestamp_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);

        const message = try std.fmt.allocPrint(
            self.allocator,
            "{{\"type\":\"yap_refined\",\"data\":{{\"text\":\"{s}\",\"revision\":{d},\"char_count\":{d},\"compression_ratio\":{d:.2},\"timestamp\":{d}}}}}",
            .{ escaped.items, revision_num, char_count, compression_ratio, timestamp_ms },
        );
        defer self.allocator.free(message);

        try self.ws_server.broadcast(message);

        std.debug.print("Broadcasted YAP refinement v{d}: {d} chars (ratio: {d:.2})\n", .{ revision_num, char_count, compression_ratio });
    }

    /// Get current state
    pub fn getState(self: *DaemonState) State {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.current_state;
    }

    /// Set YAP command (thread-safe)
    pub fn setYapCommand(self: *DaemonState, command: YapCommand, context: ?[]const u8) !void {
        self.yap_mutex.lock();
        defer self.yap_mutex.unlock();

        // Clear any existing context
        if (self.yap_refine_context) |old_ctx| {
            self.allocator.free(old_ctx);
            self.yap_refine_context = null;
        }

        // Set new command
        self.yap_command = command;

        // Store context if provided (for refine command)
        if (context) |ctx| {
            self.yap_refine_context = try self.allocator.dupe(u8, ctx);
        }

        std.debug.print("YAP command queued: {s}\n", .{command.toString()});
    }

    /// Get YAP command (thread-safe, non-blocking)
    pub fn getYapCommand(self: *DaemonState) ?YapCommand {
        self.yap_mutex.lock();
        defer self.yap_mutex.unlock();
        return self.yap_command;
    }

    /// Get YAP refine context (thread-safe, caller owns returned memory)
    pub fn getYapRefineContext(self: *DaemonState) ?[]const u8 {
        self.yap_mutex.lock();
        defer self.yap_mutex.unlock();

        if (self.yap_refine_context) |ctx| {
            // Return a copy so caller can use it safely
            return self.allocator.dupe(u8, ctx) catch null;
        }
        return null;
    }

    /// Clear YAP command (thread-safe)
    pub fn clearYapCommand(self: *DaemonState) void {
        self.yap_mutex.lock();
        defer self.yap_mutex.unlock();

        self.yap_command = null;

        if (self.yap_refine_context) |ctx| {
            self.allocator.free(ctx);
            self.yap_refine_context = null;
        }

        std.debug.print("YAP command cleared\n", .{});
    }
};

/// Handle incoming WebSocket message
pub fn handleMessage(
    allocator: std.mem.Allocator,
    message: []const u8,
    daemon_state: *DaemonState,
) !void {
    // Simple JSON parsing - look for "type" field
    // Format: {"type":"command_name",...}

    if (std.mem.indexOf(u8, message, "\"type\"")) |type_start| {
        const after_type = message[type_start + 6 ..]; // Skip "type"

        if (std.mem.indexOf(u8, after_type, "\"start_recording\"")) |_| {
            // Ignore recording commands when in YAP mode
            const current_state = daemon_state.getState();
            if (current_state == .yap_refining) {
                std.debug.print("⚠️  Ignoring start_recording - YAP mode active\n", .{});
                return;
            }

            const ts = std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC) catch unreachable;
            const ts_ms = @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, std.time.ns_per_ms);
            std.debug.print("[{d}ms] WebSocket: Received start_recording command\n", .{ts_ms});
            try daemon_state.setState(.recording);

        } else if (std.mem.indexOf(u8, after_type, "\"stop_recording\"")) |_| {
            std.debug.print("WebSocket: Received stop_recording command\n", .{});
            try daemon_state.setState(.processing);

        } else if (std.mem.indexOf(u8, after_type, "\"get_state\"")) |_| {
            std.debug.print("WebSocket: Received get_state command\n", .{});
            const state = daemon_state.getState();
            const response = try std.fmt.allocPrint(
                allocator,
                "{{\"type\":\"state_changed\",\"data\":{{\"state\":\"{s}\"}}}}",
                .{state.toString()},
            );
            defer allocator.free(response);
            try daemon_state.ws_server.broadcast(response);

        } else if (std.mem.indexOf(u8, after_type, "\"yap_accept\"")) |_| {
            std.debug.print("WebSocket: Received yap_accept command\n", .{});
            try daemon_state.setYapCommand(.accept, null);

        } else if (std.mem.indexOf(u8, after_type, "\"yap_refine\"")) |_| {
            std.debug.print("WebSocket: Received yap_refine command\n", .{});

            // Try to extract optional context from message
            // Format: {"type":"yap_refine","data":{"context":"make it shorter"}}
            var context: ?[]const u8 = null;
            if (std.mem.indexOf(u8, message, "\"context\"")) |ctx_start| {
                const after_ctx = message[ctx_start + 9 ..]; // Skip "context"
                if (std.mem.indexOf(u8, after_ctx, "\"")) |quote1_idx| {
                    const start = ctx_start + 9 + quote1_idx + 1;
                    const remaining = message[start..];
                    if (std.mem.indexOf(u8, remaining, "\"")) |quote2_idx| {
                        context = remaining[0..quote2_idx];
                    }
                }
            }

            try daemon_state.setYapCommand(.refine, context);

        } else if (std.mem.indexOf(u8, after_type, "\"yap_cancel\"")) |_| {
            std.debug.print("WebSocket: Received yap_cancel command\n", .{});
            try daemon_state.setYapCommand(.cancel, null);

        } else {
            std.debug.print("WebSocket: Unknown message type in: {s}\n", .{message});
        }
    }
}
