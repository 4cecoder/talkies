const std = @import("std");
const daemon_ws = @import("daemon_ws.zig");

// GTK C shim wrapper
const c = @cImport({
    @cInclude("daemon_status_gtk.h");
});

pub const LogLevel = enum {
    info,
    warn,
    err,
    debug,

    fn toCLevel(self: LogLevel) c.LogLevel {
        return switch (self) {
            .info => c.LOG_LEVEL_INFO,
            .warn => c.LOG_LEVEL_WARN,
            .err => c.LOG_LEVEL_ERROR,
            .debug => c.LOG_LEVEL_DEBUG,
        };
    }
};

pub const DaemonStatusWindow = struct {
    allocator: std.mem.Allocator,
    gtk_win: *c.DaemonStatusWindow,

    pub fn create(allocator: std.mem.Allocator) !*DaemonStatusWindow {
        const self = try allocator.create(DaemonStatusWindow);

        const gtk_win = c.daemon_status_window_new() orelse return error.GtkInitFailed;

        self.* = .{
            .allocator = allocator,
            .gtk_win = gtk_win,
        };

        return self;
    }

    pub fn show(self: *DaemonStatusWindow) void {
        c.daemon_status_window_show(self.gtk_win);
    }

    pub fn hide(self: *DaemonStatusWindow) void {
        c.daemon_status_window_hide(self.gtk_win);
    }

    pub fn destroy(self: *DaemonStatusWindow) void {
        c.daemon_status_window_destroy(self.gtk_win);
        self.allocator.destroy(self);
    }

    // Status updates
    pub fn setState(self: *DaemonStatusWindow, state: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, state) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_set_state(self.gtk_win, cstr.ptr);
    }

    pub fn setModel(self: *DaemonStatusWindow, model: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, model) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_set_model(self.gtk_win, cstr.ptr);
    }

    pub fn setPlatform(self: *DaemonStatusWindow, platform: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, platform) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_set_platform(self.gtk_win, cstr.ptr);
    }

    pub fn setClients(self: *DaemonStatusWindow, count: usize) void {
        c.daemon_status_window_set_clients(self.gtk_win, @intCast(count));
    }

    pub fn setYapEnabled(self: *DaemonStatusWindow, enabled: bool) void {
        c.daemon_status_window_set_yap_enabled(self.gtk_win, if (enabled) 1 else 0);
    }

    pub fn setOllamaConnected(self: *DaemonStatusWindow, connected: bool) void {
        c.daemon_status_window_set_ollama_connected(self.gtk_win, if (connected) 1 else 0);
    }

    // Activity updates
    pub fn setActivity(self: *DaemonStatusWindow, activity: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, activity) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_set_activity(self.gtk_win, cstr.ptr);
    }

    pub fn setLastTranscription(self: *DaemonStatusWindow, time: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, time) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_set_last_transcription(self.gtk_win, cstr.ptr);
    }

    // Log management
    pub fn addLog(self: *DaemonStatusWindow, level: LogLevel, message: []const u8) void {
        const cstr = self.allocator.dupeZ(u8, message) catch return;
        defer self.allocator.free(cstr);
        c.daemon_status_window_add_log(self.gtk_win, level.toCLevel(), cstr.ptr);
    }

    pub fn clearLogs(self: *DaemonStatusWindow) void {
        c.daemon_status_window_clear_logs(self.gtk_win);
    }

    // Statistics
    pub fn setStats(self: *DaemonStatusWindow, sessions: usize, errors: usize, avg_duration: f32) void {
        c.daemon_status_window_set_stats(
            self.gtk_win,
            @intCast(sessions),
            @intCast(errors),
            avg_duration,
        );
    }

    /// Process GTK events - call in tight loop to keep window responsive
    pub fn processEvents() void {
        c.daemon_status_gtk_process_events();
    }
};
