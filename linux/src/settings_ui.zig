const std = @import("std");
const config = @import("config.zig");

// GTK4 C bindings (fallback until Ghostty bindings support Zig 0.16)
const c = @cImport({
    @cInclude("gtk/gtk.h");
});

const log = std.log.scoped(.settings_ui);

/// Settings window using GTK4 C FFI
/// NOTE: Simplified version using direct C API while waiting for Zig 0.16-compatible bindings
pub const SettingsWindow = struct {
    const Self = @This();
    parent_instance: Parent,

    pub const Parent = gtk.Window;

    pub const getGObjectType = gobject.ext.defineClass(Self, .{
        .name = "TalkiesSettingsWindow",
        .instanceInit = &init,
        .classInit = &Class.init,
        .parent_class = &Class.parent,
        .private = .{ .Type = Private, .offset = &Private.offset },
    });

    const Private = struct {
        cfg: *config.Config,

        // Widget references
        audio_device_entry: ?*gtk.Entry = null,
        model_combo: ?*gtk.ComboBoxText = null,
        language_entry: ?*gtk.Entry = null,
        threads_spin: ?*gtk.SpinButton = null,
        auto_paste_switch: ?*gtk.Switch = null,

        pub var offset: c_int = 0;
    };

    /// Create a new settings window
    pub fn new(cfg: *config.Config) *Self {
        const self = gobject.ext.newInstance(Self, .{});
        self.private().cfg = cfg;
        return self;
    }

    fn init(self: *Self, _: *Class) callconv(.c) void {
        const priv = self.private();
        const window = self.as(gtk.Window);

        // Configure window
        window.setTitle("Talkies Settings");
        window.setDefaultSize(500, 400);
        window.setResizable(0); // Non-resizable

        // Create main vertical box with margins
        const vbox = gtk.Box.new(.vertical, 10);
        vbox.as(gtk.Widget).setMarginStart(20);
        vbox.as(gtk.Widget).setMarginEnd(20);
        vbox.as(gtk.Widget).setMarginTop(20);
        vbox.as(gtk.Widget).setMarginBottom(20);

        // Audio Settings section
        self.addSection(vbox, "Audio Settings");
        self.addAudioDeviceRow(vbox);

        // Transcription section
        self.addSection(vbox, "Transcription");
        self.addModelRow(vbox);
        self.addLanguageRow(vbox);
        self.addThreadsRow(vbox);

        // Output section
        self.addSection(vbox, "Output");
        self.addAutoPasteRow(vbox);

        // Button row
        self.addButtons(vbox);

        // Set as window child
        window.setChild(vbox.as(gtk.Widget));
    }

    fn addSection(self: *Self, container: *gtk.Box, title: [:0]const u8) void {
        _ = self;
        const label = gtk.Label.new(title.ptr);
        label.as(gtk.Widget).addCssClass("heading");
        label.as(gtk.Widget).setHalign(.start);
        label.as(gtk.Widget).setMarginTop(10);
        container.append(label.as(gtk.Widget));
    }

    fn addAudioDeviceRow(self: *Self, container: *gtk.Box) void {
        const priv = self.private();
        const hbox = gtk.Box.new(.horizontal, 10);

        const label = gtk.Label.new("Audio Device:");
        label.as(gtk.Widget).setSizeRequest(150, -1);
        label.as(gtk.Widget).setHalign(.start);
        hbox.append(label.as(gtk.Widget));

        const entry = gtk.Entry.new();
        priv.audio_device_entry = entry;
        entry.getBuffer().setText(priv.cfg.audio_device.ptr, -1);
        entry.as(gtk.Widget).setHexpand(@intFromBool(true));
        hbox.append(entry.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn addModelRow(self: *Self, container: *gtk.Box) void {
        const priv = self.private();
        const hbox = gtk.Box.new(.horizontal, 10);

        const label = gtk.Label.new("Whisper Model:");
        label.as(gtk.Widget).setSizeRequest(150, -1);
        label.as(gtk.Widget).setHalign(.start);
        hbox.append(label.as(gtk.Widget));

        const combo = gtk.ComboBoxText.new();
        priv.model_combo = combo;

        const models = [_][:0]const u8{ "tiny", "base", "small", "medium", "large" };
        var active_idx: c_int = 1; // default to "base"
        for (models, 0..) |model, i| {
            combo.appendText(model.ptr);
            if (std.mem.eql(u8, model, priv.cfg.model)) {
                active_idx = @intCast(i);
            }
        }
        combo.as(gtk.ComboBox).setActive(active_idx);

        combo.as(gtk.Widget).setHexpand(@intFromBool(true));
        hbox.append(combo.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn addLanguageRow(self: *Self, container: *gtk.Box) void {
        const priv = self.private();
        const hbox = gtk.Box.new(.horizontal, 10);

        const label = gtk.Label.new("Language:");
        label.as(gtk.Widget).setSizeRequest(150, -1);
        label.as(gtk.Widget).setHalign(.start);
        hbox.append(label.as(gtk.Widget));

        const entry = gtk.Entry.new();
        priv.language_entry = entry;
        entry.getBuffer().setText(priv.cfg.language.ptr, -1);
        entry.setMaxLength(5);
        entry.as(gtk.Widget).setHexpand(@intFromBool(true));
        hbox.append(entry.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn addThreadsRow(self: *Self, container: *gtk.Box) void {
        const priv = self.private();
        const hbox = gtk.Box.new(.horizontal, 10);

        const label = gtk.Label.new("CPU Threads:");
        label.as(gtk.Widget).setSizeRequest(150, -1);
        label.as(gtk.Widget).setHalign(.start);
        hbox.append(label.as(gtk.Widget));

        const adjustment = gtk.Adjustment.new(
            @floatFromInt(priv.cfg.threads), // value
            1.0,  // lower
            16.0, // upper
            1.0,  // step_increment
            4.0,  // page_increment
            0.0,  // page_size
        );

        const spin = gtk.SpinButton.new(adjustment, 1.0, 0);
        priv.threads_spin = spin;
        spin.as(gtk.Widget).setHexpand(@intFromBool(true));
        hbox.append(spin.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn addAutoPasteRow(self: *Self, container: *gtk.Box) void {
        const priv = self.private();
        const hbox = gtk.Box.new(.horizontal, 10);

        const label = gtk.Label.new("Auto-paste:");
        label.as(gtk.Widget).setSizeRequest(150, -1);
        label.as(gtk.Widget).setHalign(.start);
        hbox.append(label.as(gtk.Widget));

        const switch_widget = gtk.Switch.new();
        priv.auto_paste_switch = switch_widget;
        switch_widget.setActive(@intFromBool(priv.cfg.auto_paste));
        switch_widget.as(gtk.Widget).setHalign(.start);
        hbox.append(switch_widget.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn addButtons(self: *Self, container: *gtk.Box) void {
        const hbox = gtk.Box.new(.horizontal, 10);
        hbox.as(gtk.Widget).setHalign(.end);
        hbox.as(gtk.Widget).setMarginTop(20);

        // Cancel button
        const cancel_btn = gtk.Button.newWithLabel("Cancel");
        _ = gtk.Button.signals.clicked.connect(
            cancel_btn,
            *Self,
            onCancelClicked,
            self,
            .{},
        );
        hbox.append(cancel_btn.as(gtk.Widget));

        // Save button
        const save_btn = gtk.Button.newWithLabel("Save");
        save_btn.as(gtk.Widget).addCssClass("suggested-action");
        _ = gtk.Button.signals.clicked.connect(
            save_btn,
            *Self,
            onSaveClicked,
            self,
            .{},
        );
        hbox.append(save_btn.as(gtk.Widget));

        container.append(hbox.as(gtk.Widget));
    }

    fn onCancelClicked(_: *gtk.Button, self: *Self) callconv(.c) void {
        self.as(gtk.Window).close();
    }

    fn onSaveClicked(_: *gtk.Button, self: *Self) callconv(.c) void {
        self.saveSettings() catch |err| {
            log.err("Failed to save settings: {}", .{err});
        };
    }

    fn saveSettings(self: *Self) !void {
        const priv = self.private();

        // Read audio device
        if (priv.audio_device_entry) |entry| {
            const text = std.mem.span(entry.getBuffer().getText());
            if (priv.cfg.audio_device_owned) {
                priv.cfg.allocator.free(priv.cfg.audio_device);
            }
            priv.cfg.audio_device = try priv.cfg.allocator.dupe(u8, text);
            priv.cfg.audio_device_owned = true;
        }

        // Read model
        if (priv.model_combo) |combo| {
            const text = combo.getActiveText();
            if (text) |t| {
                defer glib.ext.free(t);
                const model = std.mem.span(t);
                if (priv.cfg.model_owned) {
                    priv.cfg.allocator.free(priv.cfg.model);
                }
                priv.cfg.model = try priv.cfg.allocator.dupe(u8, model);
                priv.cfg.model_owned = true;
            }
        }

        // Read language
        if (priv.language_entry) |entry| {
            const text = std.mem.span(entry.getBuffer().getText());
            if (priv.cfg.language_owned) {
                priv.cfg.allocator.free(priv.cfg.language);
            }
            priv.cfg.language = try priv.cfg.allocator.dupe(u8, text);
            priv.cfg.language_owned = true;
        }

        // Read threads
        if (priv.threads_spin) |spin| {
            const value = spin.getValue();
            priv.cfg.threads = @intFromFloat(value);
        }

        // Read auto-paste
        if (priv.auto_paste_switch) |switch_widget| {
            priv.cfg.auto_paste = switch_widget.getActive() != 0;
        }

        // Save to disk
        try priv.cfg.save();
        log.info("Settings saved successfully", .{});

        // Close window
        self.as(gtk.Window).close();
    }

    fn dispose(self: *Self) callconv(.c) void {
        gobject.Object.virtual_methods.dispose.call(
            Class.parent,
            self.as(Parent),
        );
    }

    // Common helper methods
    pub fn as(self: *Self, comptime T: type) *T {
        return gobject.ext.as(T, self);
    }

    pub fn ref(self: *Self) *Self {
        return gobject.ext.ref(Self, self);
    }

    pub fn unref(self: *Self) void {
        gobject.ext.unref(self);
    }

    fn private(self: *Self) *Private {
        return gobject.ext.impl_helpers.getPrivate(self, Private, Private.offset);
    }

    pub const Class = extern struct {
        parent_class: Parent.Class,
        var parent: *Parent.Class = undefined;
        pub const Instance = Self;

        fn init(class: *Class) callconv(.c) void {
            // Virtual methods
            gobject.Object.virtual_methods.dispose.implement(class, &dispose);
        }

        pub fn as(class: *Class, comptime T: type) *T {
            return gobject.ext.as(T, class);
        }
    };
};

/// Simple wrapper for backwards compatibility
pub const SettingsUI = struct {
    allocator: std.mem.Allocator,
    window: ?*SettingsWindow = null,
    cfg: *config.Config,

    pub fn init(allocator: std.mem.Allocator, cfg: *config.Config) SettingsUI {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn deinit(self: *SettingsUI) void {
        if (self.window) |win| {
            win.unref();
            self.window = null;
        }
    }

    /// Show the settings window
    pub fn show(self: *SettingsUI) !void {
        if (self.window == null) {
            self.window = SettingsWindow.new(self.cfg);
        }

        if (self.window) |win| {
            win.as(gtk.Window).present();
        }
    }
};
