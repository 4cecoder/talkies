const std = @import("std");
const yap_sandbox = @import("yap_sandbox.zig");
const daemon_ws = @import("daemon_ws.zig");

// GTK4 C shim wrapper
const c = @cImport({
    @cInclude("yap_window_gtk.h");
});

/// YAP Mode GTK Window for interactive refinement
/// Shows original transcription, refined versions, and provides Accept/Refine/Cancel buttons
pub const YapWindow = struct {
    allocator: std.mem.Allocator,
    gtk_win: *c.YapWindowGtk,
    daemon_state: *daemon_ws.DaemonState,
    sandbox: *yap_sandbox.Sandbox,
    original_chars: usize,

    pub fn create(
        allocator: std.mem.Allocator,
        sandbox: *yap_sandbox.Sandbox,
        daemon_state: *daemon_ws.DaemonState,
    ) !*YapWindow {
        const self = try allocator.create(YapWindow);

        const gtk_win = c.yap_window_gtk_new() orelse return error.GtkInitFailed;

        self.* = .{
            .allocator = allocator,
            .gtk_win = gtk_win,
            .daemon_state = daemon_state,
            .sandbox = sandbox,
            .original_chars = sandbox.yapping.len,
        };

        // Connect signal handlers
        c.yap_window_gtk_connect_signals(
            gtk_win,
            onAcceptClicked,
            onRefineClicked,
            onCancelClicked,
            self,
        );

        try self.updateDisplay();

        return self;
    }

    pub fn updateDisplay(self: *YapWindow) !void {
        // Update original text
        c.yap_window_gtk_set_original_text(
            self.gtk_win,
            self.sandbox.yapping.ptr,
            @intCast(self.sandbox.yapping.len),
        );

        // Update refined text
        const current = self.sandbox.getCurrentRefinement();
        c.yap_window_gtk_set_refined_text(
            self.gtk_win,
            current.ptr,
            @intCast(current.len),
        );

        // Update stats
        const revision_count = self.sandbox.getRevisionCount();
        const refined_chars = current.len;
        const compression_ratio = if (self.original_chars > 0)
            @as(f32, @floatFromInt(refined_chars)) / @as(f32, @floatFromInt(self.original_chars))
        else
            1.0;

        c.yap_window_gtk_set_revision(self.gtk_win, @intCast(revision_count));
        c.yap_window_gtk_set_original_chars(self.gtk_win, @intCast(self.original_chars));
        c.yap_window_gtk_set_refined_chars(self.gtk_win, @intCast(refined_chars));
        c.yap_window_gtk_set_compression(self.gtk_win, compression_ratio);

        // Update history
        const history = try self.sandbox.formatHistory();
        defer self.allocator.free(history);
        c.yap_window_gtk_set_history_text(
            self.gtk_win,
            history.ptr,
            @intCast(history.len),
        );
    }

    pub fn show(self: *YapWindow) void {
        c.yap_window_gtk_show(self.gtk_win);
    }

    pub fn hide(self: *YapWindow) void {
        c.yap_window_gtk_hide(self.gtk_win);
    }

    pub fn destroy(self: *YapWindow) void {
        c.yap_window_gtk_destroy(self.gtk_win);
        self.allocator.destroy(self);
    }

    /// Process GTK events - call in tight loop to keep window responsive
    pub fn processEvents() void {
        c.yap_window_gtk_process_events();
    }

    // Signal handlers
    fn onAcceptClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        self.daemon_state.setYapCommand(.accept, null) catch {};
        self.hide();
    }

    fn onRefineClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));

        // Get additional context from entry (internal pointer, don't free)
        const entry_text = c.yap_window_gtk_get_refine_input(self.gtk_win);

        const context = if (entry_text != null and c.strlen(entry_text) > 0)
            std.mem.span(entry_text)
        else
            null;

        self.daemon_state.setYapCommand(.refine, context) catch {};

        // Clear input
        c.yap_window_gtk_clear_refine_input(self.gtk_win);
    }

    fn onCancelClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        self.daemon_state.setYapCommand(.cancel, null) catch {};
        self.hide();
    }
};
