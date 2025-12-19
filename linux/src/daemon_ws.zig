const std = @import("std");
const websocket = @import("websocket.zig");

/// WebSocket message types for Talkies daemon
pub const MessageType = enum {
    // Commands (client → server)
    start_recording,
    stop_recording,
    get_state,

    // Events (server → client)
    state_changed,
    audio_level,
    transcription_complete,
    @"error",
};

/// Application state
pub const State = enum {
    idle,
    recording,
    processing,

    pub fn toString(self: State) []const u8 {
        return switch (self) {
            .idle => "idle",
            .recording => "recording",
            .processing => "processing",
        };
    }
};

/// Daemon state manager with WebSocket broadcasting
pub const DaemonState = struct {
    allocator: std.mem.Allocator,
    ws_server: *websocket.Server,
    current_state: State,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, ws_server: *websocket.Server) DaemonState {
        return .{
            .allocator = allocator,
            .ws_server = ws_server,
            .current_state = .idle,
            .mutex = .{},
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

    /// Get current state
    pub fn getState(self: *DaemonState) State {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.current_state;
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
            std.debug.print("WebSocket: Received start_recording command\n", .{});
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
        } else {
            std.debug.print("WebSocket: Unknown message type in: {s}\n", .{message});
        }
    }
}
