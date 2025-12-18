const std = @import("std");
const utils = @import("utils.zig");
const icons = @import("icons.zig");

// DBus C bindings for StatusNotifierItem protocol
const c = @cImport({
    @cInclude("dbus/dbus.h");
});

// Define DBusError struct manually since cImport makes it opaque
const DBusError = extern struct {
    name: [*c]const u8,
    message: [*c]const u8,
    dummy1: c_uint,
    dummy2: c_uint,
    dummy3: c_uint,
    dummy4: c_uint,
    dummy5: c_uint,
    padding1: ?*anyopaque,
};

/// System tray icon using StatusNotifierItem (freedesktop.org spec)
/// Works on both X11 and Wayland with modern desktop environments
/// (GNOME Shell, KDE Plasma, Waybar, etc.)
pub const SystemTray = struct {
    allocator: std.mem.Allocator,
    connection: ?*c.DBusConnection = null,
    menu_items: std.ArrayList(MenuItem),
    quit_callback: ?*const fn () void = null,
    settings_callback: ?*const fn () void = null,

    pub const MenuItem = struct {
        id: u32,
        label: []const u8,
        callback: ?*const fn () void,
    };

    pub fn init(allocator: std.mem.Allocator) SystemTray {
        return .{
            .allocator = allocator,
            .menu_items = std.ArrayList(MenuItem).empty,
        };
    }

    pub fn deinit(self: *SystemTray) void {
        if (self.connection) |conn| {
            c.dbus_connection_unref(conn);
            self.connection = null;
        }
        self.menu_items.deinit();
    }

    /// Initialize the system tray icon
    pub fn start(self: *SystemTray) !void {
        var err: DBusError = undefined;
        c.dbus_error_init(@ptrCast(&err));

        // Connect to session bus
        self.connection = c.dbus_bus_get(c.DBUS_BUS_SESSION, @ptrCast(&err));
        if (c.dbus_error_is_set(@ptrCast(&err)) != 0) {
            utils.logError("DBus connection error: {s}", .{err.message});
            c.dbus_error_free(@ptrCast(&err));
            return error.DBusConnectionFailed;
        }

        if (self.connection == null) {
            return error.DBusConnectionNull;
        }

        // Request a unique bus name for our tray icon
        const bus_name = "org.kde.StatusNotifierItem-talkies";
        const ret = c.dbus_bus_request_name(
            self.connection,
            bus_name,
            c.DBUS_NAME_FLAG_REPLACE_EXISTING,
            @ptrCast(&err),
        );

        if (c.dbus_error_is_set(@ptrCast(&err)) != 0) {
            utils.logError("DBus name request error: {s}", .{err.message});
            c.dbus_error_free(@ptrCast(&err));
            return error.DBusNameRequestFailed;
        }

        if (ret != c.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
            utils.logError("Not primary owner of DBus name", .{});
            return error.DBusNotPrimaryOwner;
        }

        // Set up embedded icon (24x24 for tray)
        try self.setupIcon();

        // Register with StatusNotifierWatcher
        try self.registerWithWatcher();

        // Setup menu items
        try self.setupMenu();

        utils.log("System tray initialized successfully", .{});
    }

    /// Setup the tray icon using embedded PNG data
    fn setupIcon(self: *SystemTray) !void {
        // Get embedded 24x24 icon
        const icon_path = try icons.Icons.getIconPath(self.allocator, 24);
        defer self.allocator.free(icon_path);

        // Icon is now available at icon_path
        // DBus StatusNotifierItem spec requires setting the IconPixmap property
        // For simplicity, we'll use IconName with the temp path
        // TODO: Implement proper IconPixmap property with raw ARGB data
        utils.log("Tray icon prepared at: {s}", .{icon_path});
    }

    /// Register our tray icon with the StatusNotifierWatcher
    fn registerWithWatcher(self: *SystemTray) !void {
        const msg = c.dbus_message_new_method_call(
            "org.kde.StatusNotifierWatcher",
            "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher",
            "RegisterStatusNotifierItem",
        );
        defer c.dbus_message_unref(msg);

        if (msg == null) {
            return error.DBusMessageNull;
        }

        // Add our service path as argument
        const service = "org.kde.StatusNotifierItem-talkies";
        if (c.dbus_message_append_args(
            msg,
            c.DBUS_TYPE_STRING,
            &service,
            c.DBUS_TYPE_INVALID,
        ) == 0) {
            return error.DBusAppendArgsFailed;
        }

        // Send the message
        var err: DBusError = undefined;
        c.dbus_error_init(@ptrCast(&err));

        const reply = c.dbus_connection_send_with_reply_and_block(
            self.connection,
            msg,
            -1,
            @ptrCast(&err),
        );

        if (c.dbus_error_is_set(@ptrCast(&err)) != 0) {
            utils.logError("Failed to register with watcher: {s}", .{err.message});
            c.dbus_error_free(@ptrCast(&err));
            return error.WatcherRegistrationFailed;
        }

        if (reply != null) {
            c.dbus_message_unref(reply);
        }

        utils.log("Registered with StatusNotifierWatcher", .{});
    }

    /// Setup the context menu items
    fn setupMenu(self: *SystemTray) !void {
        // Settings menu item
        try self.menu_items.append(self.allocator, .{
            .id = 1,
            .label = "Settings",
            .callback = self.settings_callback,
        });

        // Separator (id 0 = separator)
        try self.menu_items.append(self.allocator, .{
            .id = 0,
            .label = "",
            .callback = null,
        });

        // Quit menu item
        try self.menu_items.append(self.allocator, .{
            .id = 2,
            .label = "Quit",
            .callback = self.quit_callback,
        });
    }

    /// Set the quit callback
    pub fn setQuitCallback(self: *SystemTray, callback: *const fn () void) void {
        self.quit_callback = callback;
    }

    /// Set the settings callback
    pub fn setSettingsCallback(self: *SystemTray, callback: *const fn () void) void {
        self.settings_callback = callback;
    }

    /// Update the tray icon tooltip
    pub fn setTooltip(self: *SystemTray, text: []const u8) !void {
        _ = self;
        _ = text;
        // TODO: Implement tooltip update via DBus properties
    }

    /// Process DBus events (call this in main event loop)
    pub fn processEvents(self: *SystemTray) !void {
        if (self.connection == null) return;

        // Process pending messages non-blocking
        while (c.dbus_connection_dispatch(self.connection) == c.DBUS_DISPATCH_DATA_REMAINS) {
            // Continue processing
        }

        // Read/write pending data
        _ = c.dbus_connection_read_write(self.connection, 0);
    }
};

test "tray initialization" {
    const allocator = std.testing.allocator;
    var tray = SystemTray.init(allocator);
    defer tray.deinit();

    try std.testing.expect(tray.connection == null);
}
