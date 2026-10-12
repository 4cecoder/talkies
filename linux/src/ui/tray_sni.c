#include "tray_sni.h"

#include <cairo.h>
#include <dbus/dbus.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define ITEM_PATH "/StatusNotifierItem"
#define MENU_PATH "/MenuBar"
#define ITEM_IFACE "org.kde.StatusNotifierItem"
#define MENU_IFACE "com.canonical.dbusmenu"
#define WATCHER_NAME "org.kde.StatusNotifierWatcher"
#define PROPS_IFACE "org.freedesktop.DBus.Properties"
#define G_PI_LIKE 3.14159265358979323846

enum { MENU_ROOT = 0, MENU_OPEN = 1, MENU_RECORD = 2, MENU_SEP1 = 3, MENU_SETTINGS = 4, MENU_SEP2 = 5, MENU_QUIT = 6 };
static const int menu_children[] = {MENU_OPEN, MENU_RECORD, MENU_SEP1, MENU_SETTINGS, MENU_SEP2, MENU_QUIT};
#define MENU_CHILD_COUNT (int)(sizeof menu_children / sizeof menu_children[0])

struct TalkiesTray {
    DBusConnection *conn;
    char bus_name[96];
    int recording;
    char status_text[256];
    char icon_theme_path[1024];
    unsigned int menu_revision;
    TalkiesTrayCallback callback;
    void *user_data;
};

// ---------------------------------------------------------------------------
// Variant helpers
// ---------------------------------------------------------------------------

static void append_variant_string(DBusMessageIter *iter, const char *value) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "s", &v);
    dbus_message_iter_append_basic(&v, DBUS_TYPE_STRING, &value);
    dbus_message_iter_close_container(iter, &v);
}

static void append_variant_bool(DBusMessageIter *iter, dbus_bool_t value) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "b", &v);
    dbus_message_iter_append_basic(&v, DBUS_TYPE_BOOLEAN, &value);
    dbus_message_iter_close_container(iter, &v);
}

static void append_variant_uint(DBusMessageIter *iter, dbus_uint32_t value) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "u", &v);
    dbus_message_iter_append_basic(&v, DBUS_TYPE_UINT32, &value);
    dbus_message_iter_close_container(iter, &v);
}

static void append_variant_object_path(DBusMessageIter *iter, const char *value) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "o", &v);
    dbus_message_iter_append_basic(&v, DBUS_TYPE_OBJECT_PATH, &value);
    dbus_message_iter_close_container(iter, &v);
}

static void append_variant_empty_string_array(DBusMessageIter *iter) {
    DBusMessageIter v, arr;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "as", &v);
    dbus_message_iter_open_container(&v, DBUS_TYPE_ARRAY, "s", &arr);
    dbus_message_iter_close_container(&v, &arr);
    dbus_message_iter_close_container(iter, &v);
}

static void append_dict_string(DBusMessageIter *dict, const char *key, const char *value) {
    DBusMessageIter entry;
    dbus_message_iter_open_container(dict, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
    dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &key);
    append_variant_string(&entry, value);
    dbus_message_iter_close_container(dict, &entry);
}

static void append_dict_bool(DBusMessageIter *dict, const char *key, dbus_bool_t value) {
    DBusMessageIter entry;
    dbus_message_iter_open_container(dict, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
    dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &key);
    append_variant_bool(&entry, value);
    dbus_message_iter_close_container(dict, &entry);
}

// ---------------------------------------------------------------------------
// StatusNotifierItem properties
// ---------------------------------------------------------------------------

static const char *icon_name(TalkiesTray *tray) {
    if (tray->icon_theme_path[0]) {
        return tray->recording ? "talkies-tray-recording-symbolic" : "talkies-tray-symbolic";
    }
    return tray->recording ? "media-record-symbolic" : "audio-input-microphone-symbolic";
}

static const char *attention_icon_name(TalkiesTray *tray) {
    return tray->icon_theme_path[0] ? "talkies-tray-recording-symbolic" : "media-record-symbolic";
}

// ---------------------------------------------------------------------------
// Pixmap fallback (hosts that cannot resolve IconName): the same microphone
// glyph as the SVGs, rendered with cairo as ARGB32 in network byte order.
// ---------------------------------------------------------------------------

static void draw_mic(cairo_t *cr, double size, int recording) {
    cairo_scale(cr, size / 16.0, size / 16.0);
    double dx = recording ? -2.0 : 0.0, dy = recording ? 1.0 : 0.0;
    cairo_set_source_rgb(cr, 0.62, 0.64, 0.67); // neutral on light and dark panels
    // capsule
    double x = 5.5 + dx, y = 1 + dy, w = 5, h = 8.5, r = 2.5;
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + r, y + r, r, G_PI_LIKE, 1.5 * G_PI_LIKE);
    cairo_arc(cr, x + w - r, y + r, r, 1.5 * G_PI_LIKE, 2 * G_PI_LIKE);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, 0.5 * G_PI_LIKE);
    cairo_arc(cr, x + r, y + h - r, r, 0.5 * G_PI_LIKE, G_PI_LIKE);
    cairo_close_path(cr);
    cairo_fill(cr);
    // stand
    cairo_set_line_width(cr, 1.4);
    cairo_arc_negative(cr, 8 + dx, 7.5 + dy, 4.3, G_PI_LIKE, 0);
    cairo_stroke(cr);
    cairo_rectangle(cr, 7.3 + dx, 12.3 + dy, 1.4, 2);
    cairo_rectangle(cr, 5 + dx, 13.8, 6, 1.4); // base stays on the baseline
    cairo_fill(cr);
    if (recording) {
        cairo_set_source_rgb(cr, 0.855, 0.267, 0.325);
        cairo_arc(cr, 12.8, 3.4, 2.6, 0, 2 * G_PI_LIKE);
        cairo_fill(cr);
    }
}

static void append_pixmaps_value(DBusMessageIter *iter, int recording) {
    static const int sizes[] = {22, 32, 48};
    DBusMessageIter arr;
    dbus_message_iter_open_container(iter, DBUS_TYPE_ARRAY, "(iiay)", &arr);
    for (size_t i = 0; i < sizeof sizes / sizeof sizes[0]; i++) {
        int size = sizes[i];
        cairo_surface_t *surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, size, size);
        cairo_t *cr = cairo_create(surface);
        draw_mic(cr, size, recording);
        cairo_destroy(cr);
        cairo_surface_flush(surface);

        int stride = cairo_image_surface_get_stride(surface);
        const unsigned char *src = cairo_image_surface_get_data(surface);
        unsigned char *argb = malloc((size_t)size * size * 4);
        if (!argb) {
            cairo_surface_destroy(surface);
            continue;
        }
        for (int yy = 0; yy < size; yy++) {
            const uint32_t *row = (const uint32_t *)(src + yy * stride);
            for (int xx = 0; xx < size; xx++) {
                uint32_t px = row[xx]; // native-endian ARGB (premultiplied; fine for icons)
                unsigned char *dst = argb + ((size_t)yy * size + xx) * 4;
                dst[0] = (px >> 24) & 0xff;
                dst[1] = (px >> 16) & 0xff;
                dst[2] = (px >> 8) & 0xff;
                dst[3] = px & 0xff;
            }
        }
        cairo_surface_destroy(surface);

        DBusMessageIter st, bytes;
        dbus_int32_t w = size, h = size;
        dbus_message_iter_open_container(&arr, DBUS_TYPE_STRUCT, NULL, &st);
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &w);
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &h);
        dbus_message_iter_open_container(&st, DBUS_TYPE_ARRAY, "y", &bytes);
        dbus_message_iter_append_fixed_array(&bytes, DBUS_TYPE_BYTE, &argb, size * size * 4);
        dbus_message_iter_close_container(&st, &bytes);
        dbus_message_iter_close_container(&arr, &st);
        free(argb);
    }
    dbus_message_iter_close_container(iter, &arr);
}

static void append_variant_pixmaps(DBusMessageIter *iter, int recording, int empty) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "a(iiay)", &v);
    if (empty) {
        DBusMessageIter arr;
        dbus_message_iter_open_container(&v, DBUS_TYPE_ARRAY, "(iiay)", &arr);
        dbus_message_iter_close_container(&v, &arr);
    } else {
        append_pixmaps_value(&v, recording);
    }
    dbus_message_iter_close_container(iter, &v);
}

static void append_variant_int(DBusMessageIter *iter, dbus_int32_t value) {
    DBusMessageIter v;
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "i", &v);
    dbus_message_iter_append_basic(&v, DBUS_TYPE_INT32, &value);
    dbus_message_iter_close_container(iter, &v);
}

static const char *status_text(TalkiesTray *tray) {
    if (tray->status_text[0]) return tray->status_text;
    return tray->recording ? "Recording..." : "Ready";
}

static void append_tooltip_variant(TalkiesTray *tray, DBusMessageIter *iter) {
    DBusMessageIter v, st, pixmaps;
    const char *icon = icon_name(tray);
    const char *title = "Talkies";
    const char *body = status_text(tray);
    dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, "(sa(iiay)ss)", &v);
    dbus_message_iter_open_container(&v, DBUS_TYPE_STRUCT, NULL, &st);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_STRING, &icon);
    dbus_message_iter_open_container(&st, DBUS_TYPE_ARRAY, "(iiay)", &pixmaps);
    dbus_message_iter_close_container(&st, &pixmaps);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_STRING, &title);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_STRING, &body);
    dbus_message_iter_close_container(&v, &st);
    dbus_message_iter_close_container(iter, &v);
}

// Returns FALSE for unknown properties.
static int append_item_property(TalkiesTray *tray, DBusMessageIter *iter, const char *name) {
    if (!strcmp(name, "Category")) append_variant_string(iter, "ApplicationStatus");
    else if (!strcmp(name, "Id")) append_variant_string(iter, "talkies");
    else if (!strcmp(name, "Title")) append_variant_string(iter, "Talkies");
    else if (!strcmp(name, "Status")) append_variant_string(iter, tray->recording ? "NeedsAttention" : "Active");
    else if (!strcmp(name, "WindowId")) append_variant_int(iter, 0);
    else if (!strcmp(name, "IconName")) append_variant_string(iter, icon_name(tray));
    else if (!strcmp(name, "IconPixmap")) append_variant_pixmaps(iter, tray->recording, 0);
    else if (!strcmp(name, "AttentionIconName")) append_variant_string(iter, attention_icon_name(tray));
    else if (!strcmp(name, "AttentionIconPixmap")) append_variant_pixmaps(iter, 1, 0);
    else if (!strcmp(name, "AttentionMovieName")) append_variant_string(iter, "");
    else if (!strcmp(name, "OverlayIconName")) append_variant_string(iter, "");
    else if (!strcmp(name, "OverlayIconPixmap")) append_variant_pixmaps(iter, 0, 1);
    else if (!strcmp(name, "IconThemePath")) append_variant_string(iter, tray->icon_theme_path);
    else if (!strcmp(name, "ToolTip")) append_tooltip_variant(tray, iter);
    else if (!strcmp(name, "ItemIsMenu")) append_variant_bool(iter, FALSE);
    else if (!strcmp(name, "Menu")) append_variant_object_path(iter, MENU_PATH);
    else return 0;
    return 1;
}

// Full StatusNotifierItem property set: KDE Plasma reads all of these via GetAll.
static const char *const item_properties[] = {
    "Category",          "Id",          "Title",           "Status",           "WindowId",
    "IconName",          "IconPixmap",  "OverlayIconName", "OverlayIconPixmap", "AttentionIconName",
    "AttentionIconPixmap", "AttentionMovieName", "IconThemePath", "ToolTip", "ItemIsMenu", "Menu", NULL};

static int append_menu_property(TalkiesTray *tray, DBusMessageIter *iter, const char *name) {
    (void)tray;
    if (!strcmp(name, "Version")) append_variant_uint(iter, 3);
    else if (!strcmp(name, "TextDirection")) append_variant_string(iter, "ltr");
    else if (!strcmp(name, "Status")) append_variant_string(iter, "normal");
    else if (!strcmp(name, "IconThemePath")) append_variant_empty_string_array(iter);
    else return 0;
    return 1;
}

static const char *const menu_properties[] = {"Version", "TextDirection", "Status", "IconThemePath", NULL};

static DBusHandlerResult reply_properties(TalkiesTray *tray, DBusMessage *msg, int is_menu) {
    const char *iface = NULL, *name = NULL;
    DBusMessage *reply = NULL;
    if (dbus_message_is_method_call(msg, PROPS_IFACE, "Get")) {
        if (!dbus_message_get_args(msg, NULL, DBUS_TYPE_STRING, &iface, DBUS_TYPE_STRING, &name, DBUS_TYPE_INVALID))
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter;
        dbus_message_iter_init_append(reply, &iter);
        int ok = is_menu ? append_menu_property(tray, &iter, name) : append_item_property(tray, &iter, name);
        if (!ok) {
            dbus_message_unref(reply);
            reply = dbus_message_new_error(msg, DBUS_ERROR_UNKNOWN_PROPERTY, name);
        }
    } else if (dbus_message_is_method_call(msg, PROPS_IFACE, "GetAll")) {
        reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter, dict;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "{sv}", &dict);
        const char *const *names = is_menu ? menu_properties : item_properties;
        for (int i = 0; names[i]; i++) {
            DBusMessageIter entry;
            dbus_message_iter_open_container(&dict, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
            dbus_message_iter_append_basic(&entry, DBUS_TYPE_STRING, &names[i]);
            if (is_menu) append_menu_property(tray, &entry, names[i]);
            else append_item_property(tray, &entry, names[i]);
            dbus_message_iter_close_container(&dict, &entry);
        }
        dbus_message_iter_close_container(&iter, &dict);
    } else {
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
    }
    dbus_connection_send(tray->conn, reply, NULL);
    dbus_message_unref(reply);
    return DBUS_HANDLER_RESULT_HANDLED;
}

static void emit_item_signal(TalkiesTray *tray, const char *signal_name, const char *arg) {
    DBusMessage *sig = dbus_message_new_signal(ITEM_PATH, ITEM_IFACE, signal_name);
    if (!sig) return;
    if (arg) dbus_message_append_args(sig, DBUS_TYPE_STRING, &arg, DBUS_TYPE_INVALID);
    dbus_connection_send(tray->conn, sig, NULL);
    dbus_message_unref(sig);
}

static void emit_click(TalkiesTray *tray, TalkiesTrayAction action) {
    if (tray->callback) tray->callback(action, tray->user_data);
}

static const char item_introspection[] =
    "<node><interface name='org.kde.StatusNotifierItem'>"
    "<property name='Category' type='s' access='read'/><property name='Id' type='s' access='read'/>"
    "<property name='Title' type='s' access='read'/><property name='Status' type='s' access='read'/>"
    "<property name='WindowId' type='i' access='read'/><property name='IconThemePath' type='s' access='read'/>"
    "<property name='IconName' type='s' access='read'/><property name='IconPixmap' type='a(iiay)' access='read'/>"
    "<property name='OverlayIconName' type='s' access='read'/><property name='OverlayIconPixmap' type='a(iiay)' access='read'/>"
    "<property name='AttentionIconName' type='s' access='read'/><property name='AttentionIconPixmap' type='a(iiay)' access='read'/>"
    "<property name='AttentionMovieName' type='s' access='read'/>"
    "<property name='ToolTip' type='(sa(iiay)ss)' access='read'/>"
    "<property name='ItemIsMenu' type='b' access='read'/><property name='Menu' type='o' access='read'/>"
    "<method name='Activate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='SecondaryActivate'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='ContextMenu'><arg type='i' direction='in'/><arg type='i' direction='in'/></method>"
    "<method name='Scroll'><arg type='i' direction='in'/><arg type='s' direction='in'/></method>"
    "<signal name='NewIcon'/><signal name='NewAttentionIcon'/><signal name='NewOverlayIcon'/><signal name='NewTitle'/>"
    "<signal name='NewToolTip'/><signal name='NewStatus'><arg type='s'/></signal>"
    "</interface></node>";

static DBusHandlerResult reply_introspect(TalkiesTray *tray, DBusMessage *msg, const char *xml) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    dbus_message_append_args(reply, DBUS_TYPE_STRING, &xml, DBUS_TYPE_INVALID);
    dbus_connection_send(tray->conn, reply, NULL);
    dbus_message_unref(reply);
    return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult reply_empty(TalkiesTray *tray, DBusMessage *msg) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    dbus_connection_send(tray->conn, reply, NULL);
    dbus_message_unref(reply);
    return DBUS_HANDLER_RESULT_HANDLED;
}

static DBusHandlerResult item_handler(DBusConnection *conn, DBusMessage *msg, void *data) {
    (void)conn;
    TalkiesTray *tray = data;
    if (dbus_message_has_interface(msg, PROPS_IFACE)) return reply_properties(tray, msg, 0);
    if (dbus_message_is_method_call(msg, "org.freedesktop.DBus.Introspectable", "Introspect"))
        return reply_introspect(tray, msg, item_introspection);
    if (dbus_message_is_method_call(msg, ITEM_IFACE, "Activate")) {
        emit_click(tray, TALKIES_TRAY_ACTIVATE);
        return reply_empty(tray, msg);
    }
    if (dbus_message_is_method_call(msg, ITEM_IFACE, "SecondaryActivate")) {
        emit_click(tray, TALKIES_TRAY_TOGGLE_RECORD);
        return reply_empty(tray, msg);
    }
    if (dbus_message_is_method_call(msg, ITEM_IFACE, "ContextMenu")) {
        // Hosts without dbusmenu support: fall back to opening settings.
        emit_click(tray, TALKIES_TRAY_SETTINGS);
        return reply_empty(tray, msg);
    }
    if (dbus_message_is_method_call(msg, ITEM_IFACE, "Scroll")) return reply_empty(tray, msg);
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// ---------------------------------------------------------------------------
// dbusmenu
// ---------------------------------------------------------------------------

static void append_menu_item_props(TalkiesTray *tray, DBusMessageIter *dict, int id) {
    switch (id) {
    case MENU_ROOT: append_dict_string(dict, "children-display", "submenu"); break;
    case MENU_OPEN: append_dict_string(dict, "label", "Open Talkies"); break;
    case MENU_RECORD:
        append_dict_string(dict, "label", tray->recording ? "Stop Recording" : "Start Recording");
        append_dict_string(dict, "icon-name", tray->recording ? "media-playback-stop" : "media-record");
        break;
    case MENU_SETTINGS: append_dict_string(dict, "label", "Settings..."); break;
    case MENU_QUIT: append_dict_string(dict, "label", "Quit Talkies"); break;
    case MENU_SEP1:
    case MENU_SEP2: append_dict_string(dict, "type", "separator"); break;
    default: break;
    }
    if (id != MENU_ROOT) {
        append_dict_bool(dict, "enabled", TRUE);
        append_dict_bool(dict, "visible", TRUE); // libdbusmenu-qt (KDE) treats missing as hidden on some versions
    }
}

static void append_menu_node(TalkiesTray *tray, DBusMessageIter *iter, int id, int depth) {
    DBusMessageIter st, props, children;
    dbus_int32_t id32 = id;
    dbus_message_iter_open_container(iter, DBUS_TYPE_STRUCT, NULL, &st);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &id32);
    dbus_message_iter_open_container(&st, DBUS_TYPE_ARRAY, "{sv}", &props);
    append_menu_item_props(tray, &props, id);
    dbus_message_iter_close_container(&st, &props);
    dbus_message_iter_open_container(&st, DBUS_TYPE_ARRAY, "v", &children);
    if (id == MENU_ROOT && depth != 0) {
        for (int i = 0; i < MENU_CHILD_COUNT; i++) {
            DBusMessageIter v;
            dbus_message_iter_open_container(&children, DBUS_TYPE_VARIANT, "(ia{sv}av)", &v);
            append_menu_node(tray, &v, menu_children[i], depth < 0 ? -1 : depth - 1);
            dbus_message_iter_close_container(&children, &v);
        }
    }
    dbus_message_iter_close_container(&st, &children);
    dbus_message_iter_close_container(iter, &st);
}

static void handle_menu_event(TalkiesTray *tray, int id, const char *event_id) {
    if (strcmp(event_id, "clicked") != 0) return;
    switch (id) {
    case MENU_OPEN: emit_click(tray, TALKIES_TRAY_OPEN); break;
    case MENU_RECORD: emit_click(tray, TALKIES_TRAY_TOGGLE_RECORD); break;
    case MENU_SETTINGS: emit_click(tray, TALKIES_TRAY_SETTINGS); break;
    case MENU_QUIT: emit_click(tray, TALKIES_TRAY_QUIT); break;
    default: break;
    }
}

static const char menu_introspection[] =
    "<node><interface name='com.canonical.dbusmenu'>"
    "<property name='Version' type='u' access='read'/><property name='TextDirection' type='s' access='read'/>"
    "<property name='Status' type='s' access='read'/><property name='IconThemePath' type='as' access='read'/>"
    "<method name='GetLayout'><arg type='i' direction='in'/><arg type='i' direction='in'/>"
    "<arg type='as' direction='in'/><arg type='u' direction='out'/><arg type='(ia{sv}av)' direction='out'/></method>"
    "<method name='GetGroupProperties'><arg type='ai' direction='in'/><arg type='as' direction='in'/>"
    "<arg type='a(ia{sv})' direction='out'/></method>"
    "<method name='GetProperty'><arg type='i' direction='in'/><arg type='s' direction='in'/>"
    "<arg type='v' direction='out'/></method>"
    "<method name='Event'><arg type='i' direction='in'/><arg type='s' direction='in'/>"
    "<arg type='v' direction='in'/><arg type='u' direction='in'/></method>"
    "<method name='EventGroup'><arg type='a(isvu)' direction='in'/><arg type='ai' direction='out'/></method>"
    "<method name='AboutToShow'><arg type='i' direction='in'/><arg type='b' direction='out'/></method>"
    "<method name='AboutToShowGroup'><arg type='ai' direction='in'/><arg type='ai' direction='out'/>"
    "<arg type='ai' direction='out'/></method>"
    "<signal name='LayoutUpdated'><arg type='u'/><arg type='i'/></signal>"
    "</interface></node>";

static DBusHandlerResult menu_handler(DBusConnection *conn, DBusMessage *msg, void *data) {
    (void)conn;
    TalkiesTray *tray = data;
    if (dbus_message_has_interface(msg, PROPS_IFACE)) return reply_properties(tray, msg, 1);
    if (dbus_message_is_method_call(msg, "org.freedesktop.DBus.Introspectable", "Introspect"))
        return reply_introspect(tray, msg, menu_introspection);

    if (dbus_message_is_method_call(msg, MENU_IFACE, "GetLayout")) {
        DBusMessageIter args;
        dbus_int32_t parent = 0, depth = -1;
        if (dbus_message_iter_init(msg, &args)) {
            dbus_message_iter_get_basic(&args, &parent);
            if (dbus_message_iter_next(&args)) dbus_message_iter_get_basic(&args, &depth);
        }
        DBusMessage *reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter;
        dbus_message_iter_init_append(reply, &iter);
        dbus_uint32_t revision = tray->menu_revision;
        dbus_message_iter_append_basic(&iter, DBUS_TYPE_UINT32, &revision);
        append_menu_node(tray, &iter, parent, depth);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "GetGroupProperties")) {
        DBusMessageIter args, ids;
        DBusMessage *reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter, arr;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "(ia{sv})", &arr);
        if (dbus_message_iter_init(msg, &args) && dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_ARRAY) {
            dbus_message_iter_recurse(&args, &ids);
            while (dbus_message_iter_get_arg_type(&ids) == DBUS_TYPE_INT32) {
                dbus_int32_t id;
                dbus_message_iter_get_basic(&ids, &id);
                DBusMessageIter st, props;
                dbus_message_iter_open_container(&arr, DBUS_TYPE_STRUCT, NULL, &st);
                dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &id);
                dbus_message_iter_open_container(&st, DBUS_TYPE_ARRAY, "{sv}", &props);
                append_menu_item_props(tray, &props, id);
                dbus_message_iter_close_container(&st, &props);
                dbus_message_iter_close_container(&arr, &st);
                dbus_message_iter_next(&ids);
            }
        }
        dbus_message_iter_close_container(&iter, &arr);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "Event")) {
        DBusMessageIter args;
        dbus_int32_t id = 0;
        const char *event_id = "";
        if (dbus_message_iter_init(msg, &args)) {
            dbus_message_iter_get_basic(&args, &id);
            if (dbus_message_iter_next(&args)) dbus_message_iter_get_basic(&args, &event_id);
        }
        DBusMessage *reply = dbus_message_new_method_return(msg);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        handle_menu_event(tray, id, event_id);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "EventGroup")) {
        DBusMessageIter args, events;
        DBusMessage *reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter, errors;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "i", &errors);
        dbus_message_iter_close_container(&iter, &errors);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        if (dbus_message_iter_init(msg, &args) && dbus_message_iter_get_arg_type(&args) == DBUS_TYPE_ARRAY) {
            dbus_message_iter_recurse(&args, &events);
            while (dbus_message_iter_get_arg_type(&events) == DBUS_TYPE_STRUCT) {
                DBusMessageIter st;
                dbus_int32_t id = 0;
                const char *event_id = "";
                dbus_message_iter_recurse(&events, &st);
                dbus_message_iter_get_basic(&st, &id);
                if (dbus_message_iter_next(&st)) dbus_message_iter_get_basic(&st, &event_id);
                handle_menu_event(tray, id, event_id);
                dbus_message_iter_next(&events);
            }
        }
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "AboutToShow")) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        dbus_bool_t need_update = FALSE;
        dbus_message_append_args(reply, DBUS_TYPE_BOOLEAN, &need_update, DBUS_TYPE_INVALID);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "AboutToShowGroup")) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter, a, b;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "i", &a);
        dbus_message_iter_close_container(&iter, &a);
        dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "i", &b);
        dbus_message_iter_close_container(&iter, &b);
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    if (dbus_message_is_method_call(msg, MENU_IFACE, "GetProperty")) {
        DBusMessageIter args;
        dbus_int32_t id = 0;
        const char *name = "";
        if (dbus_message_iter_init(msg, &args)) {
            dbus_message_iter_get_basic(&args, &id);
            if (dbus_message_iter_next(&args)) dbus_message_iter_get_basic(&args, &name);
        }
        DBusMessage *reply = dbus_message_new_method_return(msg);
        DBusMessageIter iter;
        dbus_message_iter_init_append(reply, &iter);
        append_variant_string(&iter, !strcmp(name, "label") && id == MENU_RECORD
                                         ? (tray->recording ? "Stop Recording" : "Start Recording")
                                         : "");
        dbus_connection_send(tray->conn, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

static void emit_layout_updated(TalkiesTray *tray) {
    tray->menu_revision++;
    DBusMessage *sig = dbus_message_new_signal(MENU_PATH, MENU_IFACE, "LayoutUpdated");
    if (!sig) return;
    dbus_uint32_t revision = tray->menu_revision;
    dbus_int32_t parent = 0;
    dbus_message_append_args(sig, DBUS_TYPE_UINT32, &revision, DBUS_TYPE_INT32, &parent, DBUS_TYPE_INVALID);
    dbus_connection_send(tray->conn, sig, NULL);
    dbus_message_unref(sig);
}

// ---------------------------------------------------------------------------
// Watcher registration
// ---------------------------------------------------------------------------

static void register_with_watcher(TalkiesTray *tray) {
    DBusMessage *call = dbus_message_new_method_call(WATCHER_NAME, "/StatusNotifierWatcher", WATCHER_NAME,
                                                     "RegisterStatusNotifierItem");
    if (!call) return;
    const char *name = tray->bus_name;
    dbus_message_append_args(call, DBUS_TYPE_STRING, &name, DBUS_TYPE_INVALID);
    // Fire-and-forget: if no watcher exists yet, NameOwnerChanged re-triggers this.
    dbus_message_set_no_reply(call, TRUE);
    dbus_connection_send(tray->conn, call, NULL);
    dbus_message_unref(call);
}

static DBusHandlerResult bus_filter(DBusConnection *conn, DBusMessage *msg, void *data) {
    (void)conn;
    TalkiesTray *tray = data;
    if (dbus_message_is_signal(msg, "org.freedesktop.DBus", "NameOwnerChanged")) {
        const char *name = NULL, *old_owner = NULL, *new_owner = NULL;
        if (dbus_message_get_args(msg, NULL, DBUS_TYPE_STRING, &name, DBUS_TYPE_STRING, &old_owner,
                                  DBUS_TYPE_STRING, &new_owner, DBUS_TYPE_INVALID) &&
            !strcmp(name, WATCHER_NAME) && new_owner && new_owner[0]) {
            register_with_watcher(tray);
        }
    }
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

TalkiesTray *talkies_tray_new(TalkiesTrayCallback callback, void *user_data, const char *icon_theme_path) {
    DBusError err;
    dbus_error_init(&err);
    DBusConnection *conn = dbus_bus_get_private(DBUS_BUS_SESSION, &err);
    if (!conn) {
        fprintf(stderr, "[talkies] tray: session bus unavailable: %s\n", err.message ? err.message : "unknown");
        dbus_error_free(&err);
        return NULL;
    }
    dbus_connection_set_exit_on_disconnect(conn, FALSE);

    TalkiesTray *tray = calloc(1, sizeof *tray);
    if (!tray) {
        dbus_connection_close(conn);
        dbus_connection_unref(conn);
        return NULL;
    }
    tray->conn = conn;
    tray->callback = callback;
    tray->user_data = user_data;
    tray->menu_revision = 1;
    if (icon_theme_path) snprintf(tray->icon_theme_path, sizeof tray->icon_theme_path, "%s", icon_theme_path);
    snprintf(tray->bus_name, sizeof tray->bus_name, "org.kde.StatusNotifierItem-%d-1", (int)getpid());

    static const DBusObjectPathVTable item_vtable = {.message_function = item_handler};
    static const DBusObjectPathVTable menu_vtable = {.message_function = menu_handler};
    if (!dbus_connection_try_register_object_path(conn, ITEM_PATH, &item_vtable, tray, &err) ||
        !dbus_connection_try_register_object_path(conn, MENU_PATH, &menu_vtable, tray, &err)) {
        fprintf(stderr, "[talkies] tray: object registration failed: %s\n", err.message ? err.message : "unknown");
        dbus_error_free(&err);
        talkies_tray_destroy(tray);
        return NULL;
    }

    int ret = dbus_bus_request_name(conn, tray->bus_name, DBUS_NAME_FLAG_DO_NOT_QUEUE, &err);
    if (ret != DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER) {
        fprintf(stderr, "[talkies] tray: could not own %s: %s\n", tray->bus_name,
                err.message ? err.message : "name taken");
        dbus_error_free(&err);
        talkies_tray_destroy(tray);
        return NULL;
    }

    dbus_connection_add_filter(conn, bus_filter, tray, NULL);
    dbus_bus_add_match(conn,
                       "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',"
                       "member='NameOwnerChanged',arg0='" WATCHER_NAME "'",
                       NULL);
    register_with_watcher(tray);
    dbus_connection_flush(conn);
    return tray;
}

void talkies_tray_destroy(TalkiesTray *tray) {
    if (!tray) return;
    if (tray->conn) {
        dbus_connection_close(tray->conn);
        dbus_connection_unref(tray->conn);
    }
    free(tray);
}

void talkies_tray_process(TalkiesTray *tray) {
    if (!tray) return;
    dbus_connection_read_write(tray->conn, 0);
    while (dbus_connection_dispatch(tray->conn) == DBUS_DISPATCH_DATA_REMAINS) {
    }
    // Replies queued by the handlers above must leave now, not on the next event.
    dbus_connection_flush(tray->conn);
}

int talkies_tray_host_available(void) {
    DBusError err;
    dbus_error_init(&err);
    DBusConnection *conn = dbus_bus_get(DBUS_BUS_SESSION, &err);
    if (!conn) {
        dbus_error_free(&err);
        return 0;
    }
    dbus_bool_t has = dbus_bus_name_has_owner(conn, WATCHER_NAME, &err);
    if (dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        has = FALSE;
    }
    dbus_connection_unref(conn);
    return has ? 1 : 0;
}

int talkies_tray_get_fd(TalkiesTray *tray) {
    int fd = -1;
    if (!tray || !dbus_connection_get_unix_fd(tray->conn, &fd)) return -1;
    return fd;
}

void talkies_tray_set_recording(TalkiesTray *tray, int recording) {
    if (!tray || tray->recording == !!recording) return;
    tray->recording = !!recording;
    emit_item_signal(tray, "NewIcon", NULL);
    emit_item_signal(tray, "NewAttentionIcon", NULL);
    emit_item_signal(tray, "NewToolTip", NULL);
    emit_item_signal(tray, "NewStatus", tray->recording ? "NeedsAttention" : "Active");
    emit_layout_updated(tray);
    dbus_connection_flush(tray->conn);
}

void talkies_tray_set_status_text(TalkiesTray *tray, const char *text) {
    if (!tray) return;
    snprintf(tray->status_text, sizeof tray->status_text, "%s", text ? text : "");
    emit_item_signal(tray, "NewToolTip", NULL);
    dbus_connection_flush(tray->conn);
}
