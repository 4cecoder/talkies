const std = @import("std");
const utils = @import("utils.zig");
const config = @import("config.zig");

// GTK4 C bindings for settings window
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

/// Lightweight settings modal using native GTK4
/// Zero framework overhead, direct C FFI
pub const SettingsUI = struct {
    allocator: std.mem.Allocator,
    window: ?*c.GtkWidget = null,
    cfg: *config.Config,

    // Widget references
    audio_device_entry: ?*c.GtkWidget = null,
    model_combo: ?*c.GtkWidget = null,
    language_entry: ?*c.GtkWidget = null,
    threads_spin: ?*c.GtkWidget = null,
    auto_paste_switch: ?*c.GtkWidget = null,

    pub fn init(allocator: std.mem.Allocator, cfg: *config.Config) SettingsUI {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn deinit(self: *SettingsUI) void {
        if (self.window) |win| {
            c.gtk_window_destroy(@ptrCast(win));
            self.window = null;
        }
    }

    /// Show the settings window
    pub fn show(self: *SettingsUI) !void {
        // Initialize GTK if not already done
        if (c.gtk_is_initialized() == 0) {
            _ = c.gtk_init();
        }

        // Create window
        self.window = c.gtk_window_new();
        const win = @as(*c.GtkWindow, @ptrCast(self.window));

        c.gtk_window_set_title(win, "Talkies Settings");
        c.gtk_window_set_default_size(win, 500, 400);
        c.gtk_window_set_resizable(win, 0); // Fixed size

        // Create main container
        const vbox = c.gtk_box_new(c.GTK_ORIENTATION_VERTICAL, 10);
        c.gtk_widget_set_margin_start(vbox, 20);
        c.gtk_widget_set_margin_end(vbox, 20);
        c.gtk_widget_set_margin_top(vbox, 20);
        c.gtk_widget_set_margin_bottom(vbox, 20);
        c.gtk_window_set_child(win, vbox);

        // Audio section
        try self.addSection(vbox, "Audio Settings");
        try self.addAudioDeviceRow(vbox);

        // Transcription section
        try self.addSection(vbox, "Transcription");
        try self.addModelRow(vbox);
        try self.addLanguageRow(vbox);
        try self.addThreadsRow(vbox);

        // Output section
        try self.addSection(vbox, "Output");
        try self.addAutoPasteRow(vbox);

        // Button row
        try self.addButtons(vbox);

        // Show window
        c.gtk_window_present(win);
    }

    fn addSection(self: *SettingsUI, container: *c.GtkWidget, title: [*c]const u8) !void {
        _ = self;
        const label = c.gtk_label_new(title);
        c.gtk_widget_add_css_class(label, "heading");
        c.gtk_box_append(@ptrCast(container), label);
    }

    fn addAudioDeviceRow(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);

        const label = c.gtk_label_new("Audio Device:");
        c.gtk_widget_set_size_request(label, 150, -1);
        c.gtk_box_append(@ptrCast(hbox), label);

        self.audio_device_entry = c.gtk_entry_new();
        c.gtk_entry_set_text(@ptrCast(self.audio_device_entry), self.cfg.audio_device.ptr);
        c.gtk_widget_set_hexpand(self.audio_device_entry, 1);
        c.gtk_box_append(@ptrCast(hbox), self.audio_device_entry);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn addModelRow(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);

        const label = c.gtk_label_new("Whisper Model:");
        c.gtk_widget_set_size_request(label, 150, -1);
        c.gtk_box_append(@ptrCast(hbox), label);

        // Combo box with model options
        self.model_combo = c.gtk_combo_box_text_new();
        const combo = @as(*c.GtkComboBoxText, @ptrCast(self.model_combo));

        const models = [_][*c]const u8{ "tiny", "base", "small", "medium", "large" };
        var active_idx: i32 = 1; // default to "base"
        for (models, 0..) |model, i| {
            c.gtk_combo_box_text_append_text(combo, model);
            if (std.mem.eql(u8, std.mem.span(model), self.cfg.model)) {
                active_idx = @intCast(i);
            }
        }
        c.gtk_combo_box_set_active(@ptrCast(combo), active_idx);

        c.gtk_widget_set_hexpand(self.model_combo, 1);
        c.gtk_box_append(@ptrCast(hbox), self.model_combo);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn addLanguageRow(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);

        const label = c.gtk_label_new("Language:");
        c.gtk_widget_set_size_request(label, 150, -1);
        c.gtk_box_append(@ptrCast(hbox), label);

        self.language_entry = c.gtk_entry_new();
        c.gtk_entry_set_text(@ptrCast(self.language_entry), self.cfg.language.ptr);
        c.gtk_entry_set_max_length(@ptrCast(self.language_entry), 5);
        c.gtk_widget_set_hexpand(self.language_entry, 1);
        c.gtk_box_append(@ptrCast(hbox), self.language_entry);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn addThreadsRow(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);

        const label = c.gtk_label_new("CPU Threads:");
        c.gtk_widget_set_size_request(label, 150, -1);
        c.gtk_box_append(@ptrCast(hbox), label);

        const adjustment = c.gtk_adjustment_new(
            @floatFromInt(self.cfg.threads), // value
            1.0, // min
            16.0, // max
            1.0, // step
            4.0, // page
            0.0, // page size
        );
        self.threads_spin = c.gtk_spin_button_new(adjustment, 1.0, 0);
        c.gtk_widget_set_hexpand(self.threads_spin, 1);
        c.gtk_box_append(@ptrCast(hbox), self.threads_spin);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn addAutoPasteRow(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);

        const label = c.gtk_label_new("Auto-paste:");
        c.gtk_widget_set_size_request(label, 150, -1);
        c.gtk_box_append(@ptrCast(hbox), label);

        self.auto_paste_switch = c.gtk_switch_new();
        c.gtk_switch_set_active(@ptrCast(self.auto_paste_switch), if (self.cfg.auto_paste) 1 else 0);
        c.gtk_box_append(@ptrCast(hbox), self.auto_paste_switch);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn addButtons(self: *SettingsUI, container: *c.GtkWidget) !void {
        const hbox = c.gtk_box_new(c.GTK_ORIENTATION_HORIZONTAL, 10);
        c.gtk_widget_set_halign(hbox, c.GTK_ALIGN_END);
        c.gtk_widget_set_margin_top(hbox, 20);

        // Cancel button
        const cancel_btn = c.gtk_button_new_with_label("Cancel");
        c.g_signal_connect_data(
            cancel_btn,
            "clicked",
            @ptrCast(&onCancelClicked),
            self.window,
            null,
            0,
        );
        c.gtk_box_append(@ptrCast(hbox), cancel_btn);

        // Save button
        const save_btn = c.gtk_button_new_with_label("Save");
        c.gtk_widget_add_css_class(save_btn, "suggested-action");
        c.g_signal_connect_data(
            save_btn,
            "clicked",
            @ptrCast(&onSaveClicked),
            self,
            null,
            0,
        );
        c.gtk_box_append(@ptrCast(hbox), save_btn);

        c.gtk_box_append(@ptrCast(container), hbox);
    }

    fn onCancelClicked(button: *c.GtkButton, window: *c.GtkWidget) callconv(.C) void {
        _ = button;
        c.gtk_window_destroy(@ptrCast(window));
    }

    fn onSaveClicked(button: *c.GtkButton, user_data: *SettingsUI) callconv(.C) void {
        _ = button;
        user_data.saveSettings() catch |err| {
            utils.logError("Failed to save settings: {}", .{err});
        };
    }

    fn saveSettings(self: *SettingsUI) !void {
        // Read values from widgets
        if (self.audio_device_entry) |entry| {
            const text = c.gtk_entry_buffer_get_text(c.gtk_entry_get_buffer(@ptrCast(entry)));
            const device = std.mem.span(text);
            if (self.cfg.audio_device_owned) {
                self.cfg.allocator.free(self.cfg.audio_device);
            }
            self.cfg.audio_device = try self.cfg.allocator.dupe(u8, device);
            self.cfg.audio_device_owned = true;
        }

        if (self.model_combo) |combo| {
            const text = c.gtk_combo_box_text_get_active_text(@ptrCast(combo));
            if (text != null) {
                const model = std.mem.span(text);
                if (self.cfg.model_owned) {
                    self.cfg.allocator.free(self.cfg.model);
                }
                self.cfg.model = try self.cfg.allocator.dupe(u8, model);
                self.cfg.model_owned = true;
                c.g_free(text);
            }
        }

        if (self.language_entry) |entry| {
            const text = c.gtk_entry_buffer_get_text(c.gtk_entry_get_buffer(@ptrCast(entry)));
            const lang = std.mem.span(text);
            if (self.cfg.language_owned) {
                self.cfg.allocator.free(self.cfg.language);
            }
            self.cfg.language = try self.cfg.allocator.dupe(u8, lang);
            self.cfg.language_owned = true;
        }

        if (self.threads_spin) |spin| {
            const value = c.gtk_spin_button_get_value(@ptrCast(spin));
            self.cfg.threads = @intFromFloat(value);
        }

        if (self.auto_paste_switch) |switch_widget| {
            const active = c.gtk_switch_get_active(@ptrCast(switch_widget));
            self.cfg.auto_paste = active != 0;
        }

        // Save to disk
        try self.cfg.save();
        utils.log("Settings saved successfully", .{});

        // Close window
        if (self.window) |win| {
            c.gtk_window_destroy(@ptrCast(win));
            self.window = null;
        }
    }
};
