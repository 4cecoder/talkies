const std = @import("std");
const yap_sandbox = @import("yap_sandbox.zig");
const daemon_ws = @import("daemon_ws.zig");

// GTK4 C bindings
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

/// YAP Mode GTK Window for interactive refinement
/// Shows original transcription, refined versions, and provides Accept/Refine/Cancel buttons
pub const YapWindow = struct {
    allocator: std.mem.Allocator,
    window: *c.GtkWidget,
    daemon_state: *daemon_ws.DaemonState,

    // Text buffers
    original_buffer: *c.GtkTextBuffer,
    refined_buffer: *c.GtkTextBuffer,
    history_buffer: *c.GtkTextBuffer,

    // Input field for refinement context
    refine_input: *c.GtkWidget,

    // Stats labels
    original_chars_label: *c.GtkWidget,
    refined_chars_label: *c.GtkWidget,
    compression_label: *c.GtkWidget,
    revision_label: *c.GtkWidget,

    // Button references
    accept_btn: *c.GtkWidget,
    refine_btn: *c.GtkWidget,
    cancel_btn: *c.GtkWidget,

    // State
    sandbox: *yap_sandbox.Sandbox,
    original_chars: usize,

    pub fn create(
        allocator: std.mem.Allocator,
        sandbox: *yap_sandbox.Sandbox,
        daemon_state: *daemon_ws.DaemonState,
    ) !*YapWindow {
        const self = try allocator.create(YapWindow);
        self.* = .{
            .allocator = allocator,
            .window = undefined,
            .daemon_state = daemon_state,
            .original_buffer = undefined,
            .refined_buffer = undefined,
            .history_buffer = undefined,
            .refine_input = undefined,
            .original_chars_label = undefined,
            .refined_chars_label = undefined,
            .compression_label = undefined,
            .revision_label = undefined,
            .accept_btn = undefined,
            .refine_btn = undefined,
            .cancel_btn = undefined,
            .sandbox = sandbox,
            .original_chars = sandbox.yapping.len,
        };

        try self.buildUI();
        try self.updateDisplay();

        return self;
    }

    fn buildUI(self: *YapWindow) !void {
        // Create window
        self.window = c.gtk_window_new() orelse return error.GtkInitFailed;
        c.gtk_window_set_title(@ptrCast(self.window), "YAP Mode - Interactive Refinement");
        c.gtk_window_set_default_size(@ptrCast(self.window), 800, 600);

        // Main vertical box
        const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 10);
        c.gtk_widget_set_margin_start(vbox, 10);
        c.gtk_widget_set_margin_end(vbox, 10);
        c.gtk_widget_set_margin_top(vbox, 10);
        c.gtk_widget_set_margin_bottom(vbox, 10);
        c.gtk_window_set_child(@ptrCast(self.window), vbox);

        // Header with stats
        const header_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);
        c.gtk_box_append(@ptrCast(vbox), header_box);

        self.revision_label = c.gtk_label_new("Revision: 1") orelse return error.GtkInitFailed;
        self.original_chars_label = c.gtk_label_new("Original: 0 chars") orelse return error.GtkInitFailed;
        self.refined_chars_label = c.gtk_label_new("Refined: 0 chars") orelse return error.GtkInitFailed;
        self.compression_label = c.gtk_label_new("Compression: 100%") orelse return error.GtkInitFailed;

        c.gtk_box_append(@ptrCast(header_box), self.revision_label);
        c.gtk_box_append(@ptrCast(header_box), self.original_chars_label);
        c.gtk_box_append(@ptrCast(header_box), self.refined_chars_label);
        c.gtk_box_append(@ptrCast(header_box), self.compression_label);

        // Paned view for original and refined
        const paned = c.gtk_paned_new(c.GTK_ORIENTATION_HORIZONTAL);
        c.gtk_widget_set_vexpand(paned, 1);
        c.gtk_box_append(@ptrCast(vbox), paned);

        // Left side: Original transcription
        const left_vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 5);
        const original_label = c.gtk_label_new("📝 Original Transcription") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(left_vbox), original_label);

        const original_scroll = c.gtk_scrolled_window_new();
        c.gtk_widget_set_vexpand(original_scroll, 1);
        const original_view = c.gtk_text_view_new() orelse return error.GtkInitFailed;
        c.gtk_text_view_set_editable(@ptrCast(original_view), 0);
        c.gtk_text_view_set_wrap_mode(@ptrCast(original_view), c.GTK_WRAP_WORD);
        self.original_buffer = c.gtk_text_view_get_buffer(@ptrCast(original_view));
        c.gtk_scrolled_window_set_child(@ptrCast(original_scroll), original_view);
        c.gtk_box_append(@ptrCast(left_vbox), original_scroll);

        c.gtk_paned_set_start_child(@ptrCast(paned), left_vbox);

        // Right side: Refined version
        const right_vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 5);
        const refined_label = c.gtk_label_new("✨ Refined Version") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(right_vbox), refined_label);

        const refined_scroll = c.gtk_scrolled_window_new();
        c.gtk_widget_set_vexpand(refined_scroll, 1);
        const refined_view = c.gtk_text_view_new() orelse return error.GtkInitFailed;
        c.gtk_text_view_set_editable(@ptrCast(refined_view), 0);
        c.gtk_text_view_set_wrap_mode(@ptrCast(refined_view), c.GTK_WRAP_WORD);
        self.refined_buffer = c.gtk_text_view_get_buffer(@ptrCast(refined_view));
        c.gtk_scrolled_window_set_child(@ptrCast(refined_scroll), refined_view);
        c.gtk_box_append(@ptrCast(right_vbox), refined_scroll);

        c.gtk_paned_set_end_child(@ptrCast(paned), right_vbox);

        // History section (collapsible)
        const history_expander = c.gtk_expander_new("📜 Revision History");
        c.gtk_box_append(@ptrCast(vbox), history_expander);

        const history_scroll = c.gtk_scrolled_window_new();
        c.gtk_widget_set_size_request(history_scroll, -1, 150);
        const history_view = c.gtk_text_view_new() orelse return error.GtkInitFailed;
        c.gtk_text_view_set_editable(@ptrCast(history_view), 0);
        c.gtk_text_view_set_wrap_mode(@ptrCast(history_view), c.GTK_WRAP_WORD);
        self.history_buffer = c.gtk_text_view_get_buffer(@ptrCast(history_view));
        c.gtk_scrolled_window_set_child(@ptrCast(history_scroll), history_view);
        c.gtk_expander_set_child(@ptrCast(history_expander), history_scroll);

        // Refine input section
        const refine_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 5);
        c.gtk_box_append(@ptrCast(vbox), refine_box);

        const refine_label = c.gtk_label_new("Additional instructions:") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(refine_box), refine_label);

        self.refine_input = c.gtk_entry_new() orelse return error.GtkInitFailed;
        c.gtk_entry_set_placeholder_text(@ptrCast(self.refine_input), "e.g. Make it shorter, more formal, etc.");
        c.gtk_widget_set_hexpand(self.refine_input, 1);
        c.gtk_box_append(@ptrCast(refine_box), self.refine_input);

        // Button row
        const btn_box = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);
        c.gtk_box_set_halign(@ptrCast(btn_box), c.GTK_ALIGN_END);
        c.gtk_box_append(@ptrCast(vbox), btn_box);

        self.cancel_btn = c.gtk_button_new_with_label("❌ Cancel (use original)") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(btn_box), self.cancel_btn);

        self.refine_btn = c.gtk_button_new_with_label("🔄 Refine Again") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(btn_box), self.refine_btn);

        self.accept_btn = c.gtk_button_new_with_label("✅ Accept & Paste") orelse return error.GtkInitFailed;
        c.gtk_box_append(@ptrCast(btn_box), self.accept_btn);

        // Connect signals
        _ = c.g_signal_connect_data(
            self.accept_btn,
            "clicked",
            @ptrCast(&onAcceptClicked),
            self,
            null,
            0,
        );

        _ = c.g_signal_connect_data(
            self.refine_btn,
            "clicked",
            @ptrCast(&onRefineClicked),
            self,
            null,
            0,
        );

        _ = c.g_signal_connect_data(
            self.cancel_btn,
            "clicked",
            @ptrCast(&onCancelClicked),
            self,
            null,
            0,
        );
    }

    fn updateDisplay(self: *YapWindow) !void {
        // Update original text
        c.gtk_text_buffer_set_text(self.original_buffer, self.sandbox.yapping.ptr, @intCast(self.sandbox.yapping.len));

        // Update refined text
        const current = self.sandbox.getCurrentRefinement();
        c.gtk_text_buffer_set_text(self.refined_buffer, current.ptr, @intCast(current.len));

        // Update stats
        const revision_count = self.sandbox.getRevisionCount();
        const refined_chars = current.len;
        const compression_ratio = if (self.original_chars > 0)
            @as(f32, @floatFromInt(refined_chars)) / @as(f32, @floatFromInt(self.original_chars))
        else
            1.0;

        var buf: [256]u8 = undefined;

        const rev_text = try std.fmt.bufPrintZ(&buf, "Revision: {d}", .{revision_count});
        c.gtk_label_set_text(@ptrCast(self.revision_label), rev_text.ptr);

        const orig_text = try std.fmt.bufPrintZ(&buf, "Original: {d} chars", .{self.original_chars});
        c.gtk_label_set_text(@ptrCast(self.original_chars_label), orig_text.ptr);

        const refined_text = try std.fmt.bufPrintZ(&buf, "Refined: {d} chars", .{refined_chars});
        c.gtk_label_set_text(@ptrCast(self.refined_chars_label), refined_text.ptr);

        const comp_text = try std.fmt.bufPrintZ(&buf, "Compression: {d:.0}%", .{compression_ratio * 100.0});
        c.gtk_label_set_text(@ptrCast(self.compression_label), comp_text.ptr);

        // Update history
        const history = try self.sandbox.formatHistory();
        defer self.allocator.free(history);
        c.gtk_text_buffer_set_text(self.history_buffer, history.ptr, @intCast(history.len));
    }

    pub fn show(self: *YapWindow) void {
        c.gtk_widget_set_visible(self.window, 1);
    }

    pub fn hide(self: *YapWindow) void {
        c.gtk_widget_set_visible(self.window, 0);
    }

    pub fn destroy(self: *YapWindow) void {
        c.gtk_window_destroy(@ptrCast(self.window));
        self.allocator.destroy(self);
    }

    // Signal handlers
    fn onAcceptClicked(_: *c.GtkButton, user_data: ?*anyopaque) callconv(.C) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        self.daemon_state.setYapCommand(.accept, null) catch {};
        self.hide();
    }

    fn onRefineClicked(_: *c.GtkButton, user_data: ?*anyopaque) callconv(.C) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));

        // Get additional context from entry
        const entry_text = c.gtk_editable_get_text(@ptrCast(self.refine_input));
        const context = if (entry_text != null and c.strlen(entry_text) > 0)
            std.mem.span(entry_text)
        else
            null;

        self.daemon_state.setYapCommand(.refine, context) catch {};

        // Clear input
        c.gtk_editable_set_text(@ptrCast(self.refine_input), "");
    }

    fn onCancelClicked(_: *c.GtkButton, user_data: ?*anyopaque) callconv(.C) void {
        const self: *YapWindow = @ptrCast(@alignCast(user_data));
        self.daemon_state.setYapCommand(.cancel, null) catch {};
        self.hide();
    }
};
