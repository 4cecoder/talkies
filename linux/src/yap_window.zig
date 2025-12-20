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
    current_revision_index: usize,

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
            .current_revision_index = 0,
        };

        // Connect signal handlers
        c.yap_window_gtk_connect_signals(
            gtk_win,
            onAcceptClicked,
            onRefineClicked,
            onCancelClicked,
            onPrevRevisionClicked,
            onNextRevisionClicked,
            self,
        );

        try self.updateDisplay();

        return self;
    }

    pub fn updateDisplay(self: *YapWindow) !void {
        // Update sandbox with transcription
        c.yap_window_gtk_set_sandbox_text(
            self.gtk_win,
            self.sandbox.yapping.ptr,
            @intCast(self.sandbox.yapping.len),
        );

        // Update sandbox stats
        c.yap_window_gtk_set_sandbox_chars(self.gtk_win, @intCast(self.sandbox.yapping.len));

        // Update revision count and display latest
        const revision_count = self.sandbox.getRevisionCount();
        c.yap_window_gtk_set_revision_count(self.gtk_win, @intCast(revision_count));

        if (revision_count > 0) {
            // Show latest revision by default
            self.current_revision_index = revision_count - 1;
            try self.displayRevision(self.current_revision_index);
        }
    }

    fn displayRevision(self: *YapWindow, index: usize) !void {
        if (self.sandbox.getRevision(index)) |text| {
            // Create null-terminated string for C
            const cstr = try self.allocator.dupeZ(u8, text);
            defer self.allocator.free(cstr);

            c.yap_window_gtk_set_revision_text(
                self.gtk_win,
                cstr.ptr,
                @intCast(text.len),
            );

            // Update stats
            if (self.sandbox.getRevisionInfo(index)) |info| {
                c.yap_window_gtk_set_revision_stats(
                    self.gtk_win,
                    @intCast(info.chars),
                    @intCast(info.timestamp),
                );
            }

            c.yap_window_gtk_set_current_revision_index(self.gtk_win, @intCast(index));
        }
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

        // Get context text (Part 1 - optional initial context)
        const context_text = c.yap_window_gtk_get_context_text(self.gtk_win);
        const context = if (context_text != null and c.strlen(context_text) > 0)
            std.mem.span(context_text)
        else
            null;

        // Get sandbox text (Part 2 - main transcription area)
        const sandbox_text = c.yap_window_gtk_get_sandbox_text(self.gtk_win);

        // Update sandbox in backend with edited text from GUI
        if (sandbox_text != null and c.strlen(sandbox_text) > 0) {
            const text = std.mem.span(sandbox_text);
            self.sandbox.yapping = self.allocator.dupe(u8, text) catch return;
        }

        // Trigger refinement with context
        self.daemon_state.setYapCommand(.refine, context) catch {};
    }

    fn onCancelClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        self.daemon_state.setYapCommand(.cancel, null) catch {};
        self.hide();
    }

    fn onPrevRevisionClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        if (self.current_revision_index > 0) {
            self.current_revision_index -= 1;
            self.displayRevision(self.current_revision_index) catch {};
        }
    }

    fn onNextRevisionClicked(user_data: ?*anyopaque) callconv(.c) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        const total = self.sandbox.getRevisionCount();
        if (self.current_revision_index < total - 1) {
            self.current_revision_index += 1;
            self.displayRevision(self.current_revision_index) catch {};
        }
    }
};
