#include "hud_gtk.h"

#include <gtk/gtk.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifdef TALKIES_HAVE_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk/x11/gdkx.h>
#endif

#define HUD_WIDTH 520
#define HUD_HEIGHT 140
#define HUD_RADIUS 28.0
#define BAR_COUNT 60
#define PREVIEW_CHARS_DONE 50
#define PREVIEW_CHARS_IDLE 60

struct TalkiesHud {
    GtkWidget *window;
    GtkWidget *canvas;
    GtkWidget *status_label;
    GtkWidget *record_button;
    GtkWidget *footer_icon;
    GtkWidget *footer_spinner;
    GtkWidget *footer_label;

    TalkiesHudStage stage;
    char *detail;
    char *transcript;
    char *hotkey_name;
    double elapsed;
    float level;
    float smoothed_level;
    float jitter[BAR_COUNT];
    gint64 start_us;
    guint tick_id;

    TalkiesHudCallback record_callback;
    void *record_user_data;
};

typedef struct {
    double r, g, b;
} Rgb;

// Same palette as AnimatedMeshGradient.swift.
static const Rgb blob_colors[5] = {
    {0.1, 0.2, 0.6}, {0.3, 0.1, 0.7}, {0.5, 0.0, 0.8}, {0.1, 0.4, 0.9}, {0.2, 0.1, 0.5},
};

static Rgb stage_color(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_RECORDING: return (Rgb){1.0, 0.23, 0.19};
    case TALKIES_HUD_TRANSCRIBING: return (Rgb){1.0, 0.58, 0.0};
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return (Rgb){0.69, 0.32, 0.87};
    case TALKIES_HUD_INSERTING: return (Rgb){0.0, 0.48, 1.0};
    case TALKIES_HUD_COMPLETE: return (Rgb){0.2, 0.78, 0.35};
    case TALKIES_HUD_ERROR: return (Rgb){1.0, 0.23, 0.19};
    case TALKIES_HUD_LOADING_MODEL: return (Rgb){1.0, 0.8, 0.0};
    case TALKIES_HUD_IDLE:
    default: return (Rgb){0.6, 0.6, 0.65};
    }
}

static const char *stage_icon(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_RECORDING: return "audio-input-microphone-symbolic";
    case TALKIES_HUD_TRANSCRIBING: return "audio-x-generic-symbolic";
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return "starred-symbolic";
    case TALKIES_HUD_INSERTING: return "insert-text-symbolic";
    case TALKIES_HUD_COMPLETE: return "emblem-ok-symbolic";
    case TALKIES_HUD_ERROR: return "dialog-warning-symbolic";
    default: return "audio-input-microphone-symbolic";
    }
}

static gboolean stage_is_processing(TalkiesHudStage stage) {
    return stage == TALKIES_HUD_TRANSCRIBING || stage == TALKIES_HUD_CLEANING ||
           stage == TALKIES_HUD_ENHANCING_OLLAMA || stage == TALKIES_HUD_ENHANCING_LM_STUDIO ||
           stage == TALKIES_HUD_INSERTING;
}

// Truncate on a UTF-8 boundary and append an ellipsis when shortened.
static char *preview_text(const char *text, glong max_chars) {
    if (!text) return g_strdup("");
    glong len = g_utf8_strlen(text, -1);
    if (len <= max_chars) return g_strdup(text);
    const char *end = g_utf8_offset_to_pointer(text, max_chars);
    char *head = g_strndup(text, (gsize)(end - text));
    char *result = g_strconcat(head, "…", NULL);
    g_free(head);
    return result;
}

static void refresh_labels(TalkiesHud *hud) {
    char buf[256];
    const char *status = NULL;
    switch (hud->stage) {
    case TALKIES_HUD_IDLE:
        g_snprintf(buf, sizeof buf, "Press %s to start", hud->hotkey_name ? hud->hotkey_name : "the hotkey");
        status = buf;
        break;
    case TALKIES_HUD_LOADING_MODEL: status = "Loading model..."; break;
    case TALKIES_HUD_RECORDING: {
        int total = (int)hud->elapsed;
        g_snprintf(buf, sizeof buf, "Recording - %02d:%02d", total / 60, total % 60);
        status = buf;
        break;
    }
    case TALKIES_HUD_TRANSCRIBING: status = "Transcribing..."; break;
    case TALKIES_HUD_CLEANING: status = "Cleaning up with S1-mini..."; break;
    case TALKIES_HUD_ENHANCING_OLLAMA: status = "Enhancing with Ollama..."; break;
    case TALKIES_HUD_ENHANCING_LM_STUDIO: status = "Enhancing with LM Studio..."; break;
    case TALKIES_HUD_INSERTING: status = "Inserting text..."; break;
    case TALKIES_HUD_COMPLETE: status = "Done!"; break;
    case TALKIES_HUD_ERROR:
        g_snprintf(buf, sizeof buf, "Error: %s", hud->detail ? hud->detail : "unknown");
        status = buf;
        break;
    }
    gtk_label_set_text(GTK_LABEL(hud->status_label), status);

    gboolean processing = stage_is_processing(hud->stage);
    gtk_widget_set_visible(hud->footer_spinner, processing);
    gtk_spinner_set_spinning(GTK_SPINNER(hud->footer_spinner), processing);

    char *footer = NULL;
    gboolean show_icon = TRUE;
    if (processing) {
        footer = g_strdup(status);
    } else if (hud->stage == TALKIES_HUD_COMPLETE) {
        footer = preview_text(hud->transcript, PREVIEW_CHARS_DONE);
    } else if (hud->stage == TALKIES_HUD_ERROR) {
        footer = g_strdup(""); // the status line already says "Error: ..."
        show_icon = FALSE;
    } else if (hud->transcript && hud->transcript[0]) {
        footer = preview_text(hud->transcript, PREVIEW_CHARS_IDLE);
        show_icon = FALSE;
    } else {
        footer = g_strdup("");
        show_icon = FALSE;
    }
    gtk_label_set_text(GTK_LABEL(hud->footer_label), footer);
    g_free(footer);
    gtk_image_set_from_icon_name(GTK_IMAGE(hud->footer_icon), stage_icon(hud->stage));
    gtk_widget_set_visible(hud->footer_icon, show_icon && hud->stage != TALKIES_HUD_IDLE);

    gtk_button_set_icon_name(GTK_BUTTON(hud->record_button),
                             hud->stage == TALKIES_HUD_RECORDING ? "media-playback-stop-symbolic"
                                                                 : "audio-input-microphone-symbolic");
    if (hud->stage == TALKIES_HUD_RECORDING) {
        gtk_widget_add_css_class(hud->record_button, "recording");
    } else {
        gtk_widget_remove_css_class(hud->record_button, "recording");
    }
}

static void rounded_rect(cairo_t *cr, double x, double y, double w, double h, double r) {
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - r, y + r, r, -G_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, G_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, G_PI / 2, G_PI);
    cairo_arc(cr, x + r, y + r, r, G_PI, 3 * G_PI / 2);
    cairo_close_path(cr);
}

static void draw_backdrop(TalkiesHud *hud, cairo_t *cr, int w, int h, double t) {
    rounded_rect(cr, 0.5, 0.5, w - 1, h - 1, HUD_RADIUS);
    cairo_save(cr);
    cairo_clip_preserve(cr);

    // Black tint (DictationView uses black @ 0.75 over a blurred backdrop).
    cairo_set_source_rgba(cr, 0.02, 0.02, 0.05, 0.86);
    cairo_fill_preserve(cr);

    // Moving radial blobs, like AnimatedMeshGradient (opacity ~0.4).
    for (int i = 0; i < 5; i++) {
        double phase = t * (0.25 + 0.07 * i) + i * 1.3;
        double cx = w * (0.5 + 0.38 * sin(phase));
        double cy = h * (0.5 + 0.45 * cos(phase * 0.8 + i));
        double radius = w * (0.35 + 0.05 * sin(phase * 1.7));
        cairo_pattern_t *p = cairo_pattern_create_radial(cx, cy, 0, cx, cy, radius);
        cairo_pattern_add_color_stop_rgba(p, 0, blob_colors[i].r, blob_colors[i].g, blob_colors[i].b, 0.40);
        cairo_pattern_add_color_stop_rgba(p, 1, blob_colors[i].r, blob_colors[i].g, blob_colors[i].b, 0.0);
        cairo_set_source(cr, p);
        cairo_paint(cr);
        cairo_pattern_destroy(p);
    }

    // Subtle diagonal sheen.
    cairo_pattern_t *sheen = cairo_pattern_create_linear(0, 0, w, h);
    cairo_pattern_add_color_stop_rgba(sheen, 0, 1, 1, 1, 0.06);
    cairo_pattern_add_color_stop_rgba(sheen, 1, 0, 0, 0, 0.10);
    cairo_set_source(cr, sheen);
    cairo_paint(cr);
    cairo_pattern_destroy(sheen);
    cairo_restore(cr);

    // 0.8px white gradient border.
    cairo_pattern_t *border = cairo_pattern_create_linear(0, 0, w, h);
    cairo_pattern_add_color_stop_rgba(border, 0, 1, 1, 1, 0.35);
    cairo_pattern_add_color_stop_rgba(border, 1, 1, 1, 1, 0.08);
    cairo_set_source(cr, border);
    cairo_set_line_width(cr, 0.8);
    cairo_stroke(cr);
    cairo_pattern_destroy(border);
    (void)hud;
}

static void draw_status_dot(TalkiesHud *hud, cairo_t *cr, double t) {
    Rgb c = stage_color(hud->stage);
    double x = 26, y = 26;
    double pulse = hud->stage == TALKIES_HUD_RECORDING ? 0.5 + 0.5 * sin(t * 6.0) : 1.0;
    cairo_pattern_t *glow = cairo_pattern_create_radial(x, y, 0, x, y, 9);
    cairo_pattern_add_color_stop_rgba(glow, 0, c.r, c.g, c.b, 0.6 * pulse);
    cairo_pattern_add_color_stop_rgba(glow, 1, c.r, c.g, c.b, 0);
    cairo_set_source(cr, glow);
    cairo_arc(cr, x, y, 9, 0, 2 * G_PI);
    cairo_fill(cr);
    cairo_pattern_destroy(glow);
    cairo_set_source_rgb(cr, c.r, c.g, c.b);
    cairo_arc(cr, x, y, 2.5, 0, 2 * G_PI);
    cairo_fill(cr);
}

static void draw_waveform(TalkiesHud *hud, cairo_t *cr, int w) {
    const double area_top = 44, area_h = 60, mid = area_top + area_h / 2;
    const double gap = 2.0, margin = 20.0;
    const double bar_w = (w - 2 * margin - gap * (BAR_COUNT - 1)) / BAR_COUNT;
    const gboolean live = hud->stage == TALKIES_HUD_RECORDING;
    const float level = hud->smoothed_level;

    double r = 0.3, g = 0.95, b = 0.6; // green
    if (level > 0.7f) {
        r = 1.0; g = 0.2; b = 0.3;
    } else if (level > 0.4f) {
        r = 1.0; g = 0.6; b = 0.1;
    }

    for (int i = 0; i < BAR_COUNT; i++) {
        double height = 4.0;
        if (live) {
            double dist = fabs(i - (BAR_COUNT - 1) / 2.0) / ((BAR_COUNT - 1) / 2.0);
            double weight = 1.0 - 0.6 * dist * dist;
            height = 4.0 + level * weight * (area_h - 4.0) * hud->jitter[i];
            if (height > area_h) height = area_h;
        }
        double x = margin + i * (bar_w + gap);
        rounded_rect(cr, x, mid - height / 2, bar_w, height, bar_w / 2);
        if (live) {
            cairo_set_source_rgba(cr, r, g, b, 0.95);
        } else {
            cairo_set_source_rgba(cr, 1, 1, 1, 0.25);
        }
        cairo_fill(cr);
    }
}

static void draw_canvas(GtkDrawingArea *area, cairo_t *cr, int w, int h, gpointer user_data) {
    (void)area;
    TalkiesHud *hud = user_data;
    double t = (g_get_monotonic_time() - hud->start_us) / 1e6;

    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    draw_backdrop(hud, cr, w, h, t);
    draw_status_dot(hud, cr, t);
    draw_waveform(hud, cr, w);
}

static gboolean on_tick(GtkWidget *widget, GdkFrameClock *clock, gpointer user_data) {
    (void)clock;
    TalkiesHud *hud = user_data;
    // Spring-ish easing toward the latest level.
    hud->smoothed_level += (hud->level - hud->smoothed_level) * 0.35f;
    gtk_widget_queue_draw(widget);
    return G_SOURCE_CONTINUE;
}

static void on_record_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    if (hud->record_callback) hud->record_callback(hud->record_user_data);
}

static gboolean on_close_request(GtkWindow *window, gpointer user_data) {
    (void)user_data;
    gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
    return TRUE;
}

#ifdef TALKIES_HAVE_X11
// GTK4 dropped accept-focus/keep-above; set the equivalent X11 hints directly
// so the HUD never steals keyboard focus from the app being dictated into.
static void apply_x11_hints(TalkiesHud *hud) {
    GdkDisplay *display = gtk_widget_get_display(hud->window);
    if (!GDK_IS_X11_DISPLAY(display)) return;
    GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(hud->window));
    if (!surface) return;
    Display *xdpy = gdk_x11_display_get_xdisplay(display);
    Window xid = gdk_x11_surface_get_xid(surface);

    XWMHints *hints = XAllocWMHints();
    if (hints) {
        hints->flags = InputHint;
        hints->input = False;
        XSetWMHints(xdpy, xid, hints);
        XFree(hints);
    }

    Atom type = XInternAtom(xdpy, "_NET_WM_WINDOW_TYPE", False);
    Atom notification = XInternAtom(xdpy, "_NET_WM_WINDOW_TYPE_NOTIFICATION", False);
    XChangeProperty(xdpy, xid, type, XA_ATOM, 32, PropModeReplace, (unsigned char *)&notification, 1);

    Atom state = XInternAtom(xdpy, "_NET_WM_STATE", False);
    Atom states[3] = {
        XInternAtom(xdpy, "_NET_WM_STATE_ABOVE", False),
        XInternAtom(xdpy, "_NET_WM_STATE_STICKY", False),
        XInternAtom(xdpy, "_NET_WM_STATE_SKIP_TASKBAR", False),
    };
    XChangeProperty(xdpy, xid, state, XA_ATOM, 32, PropModeReplace, (unsigned char *)states, 3);

    // Centered horizontally, 100px above the vertical center (as on macOS).
    int screen = DefaultScreen(xdpy);
    int sw = DisplayWidth(xdpy, screen), sh = DisplayHeight(xdpy, screen);
    XMoveWindow(xdpy, xid, (sw - HUD_WIDTH) / 2, (sh - HUD_HEIGHT) / 2 - 100);
    XFlush(xdpy);
}
#endif

static void on_realize(GtkWidget *widget, gpointer user_data) {
    (void)widget;
#ifdef TALKIES_HAVE_X11
    apply_x11_hints(user_data);
#else
    (void)user_data;
#endif
}

static const char *hud_css =
    "window.talkies-hud { background: transparent; box-shadow: none; }"
    ".talkies-hud .status { color: rgba(255,255,255,0.92); font-size: 9pt; font-weight: 600; }"
    ".talkies-hud .footer { color: rgba(255,255,255,0.78); font-size: 9.5pt; }"
    ".talkies-hud .footer-icon { color: rgba(255,255,255,0.78); }"
    ".talkies-hud button.record { min-width: 28px; min-height: 28px; padding: 0; border-radius: 999px;"
    "  background: rgba(255,255,255,0.14); border: 1px solid rgba(255,255,255,0.25); color: white;"
    "  box-shadow: none; transition: all 120ms ease-out; }"
    ".talkies-hud button.record:hover { background: rgba(255,255,255,0.24); }"
    ".talkies-hud button.record.recording { background: linear-gradient(135deg, #ff5f57, #d70015);"
    "  border-color: rgba(255,255,255,0.4); }";

TalkiesHud *talkies_hud_new(void) {
    if (!gtk_is_initialized() && !gtk_init_check()) return NULL;

    TalkiesHud *hud = g_malloc0(sizeof *hud);
    hud->start_us = g_get_monotonic_time();
    for (int i = 0; i < BAR_COUNT; i++) hud->jitter[i] = 1.0f;

    hud->window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(hud->window), "Talkies Dictation");
    gtk_window_set_decorated(GTK_WINDOW(hud->window), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(hud->window), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(hud->window), HUD_WIDTH, HUD_HEIGHT);
    gtk_widget_set_focusable(hud->window, FALSE);
    gtk_widget_add_css_class(hud->window, "talkies-hud");
    g_signal_connect(hud->window, "close-request", G_CALLBACK(on_close_request), hud);
    g_signal_connect(hud->window, "realize", G_CALLBACK(on_realize), hud);

    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_string(css, hud_css);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(css),
                                               GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(css);

    // GtkWindowHandle makes the whole pill draggable.
    GtkWidget *handle = gtk_window_handle_new();
    GtkWidget *overlay = gtk_overlay_new();
    gtk_window_handle_set_child(GTK_WINDOW_HANDLE(handle), overlay);
    gtk_window_set_child(GTK_WINDOW(hud->window), handle);

    hud->canvas = gtk_drawing_area_new();
    gtk_drawing_area_set_content_width(GTK_DRAWING_AREA(hud->canvas), HUD_WIDTH);
    gtk_drawing_area_set_content_height(GTK_DRAWING_AREA(hud->canvas), HUD_HEIGHT);
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(hud->canvas), draw_canvas, hud, NULL);
    gtk_overlay_set_child(GTK_OVERLAY(overlay), hud->canvas);

    GtkWidget *column = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_margin_start(column, 20);
    gtk_widget_set_margin_end(column, 14);
    gtk_widget_set_margin_top(column, 12);
    gtk_widget_set_margin_bottom(column, 12);
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), column);

    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(top, 20); // room for the status dot drawn at x=26
    hud->status_label = gtk_label_new("");
    gtk_widget_add_css_class(hud->status_label, "status");
    gtk_label_set_xalign(GTK_LABEL(hud->status_label), 0);
    gtk_label_set_ellipsize(GTK_LABEL(hud->status_label), PANGO_ELLIPSIZE_END);
    gtk_widget_set_hexpand(hud->status_label, TRUE);
    gtk_box_append(GTK_BOX(top), hud->status_label);

    hud->record_button = gtk_button_new_from_icon_name("audio-input-microphone-symbolic");
    gtk_widget_add_css_class(hud->record_button, "record");
    gtk_widget_set_focusable(hud->record_button, FALSE);
    gtk_widget_set_valign(hud->record_button, GTK_ALIGN_CENTER);
    g_signal_connect(hud->record_button, "clicked", G_CALLBACK(on_record_clicked), hud);
    gtk_box_append(GTK_BOX(top), hud->record_button);
    gtk_box_append(GTK_BOX(column), top);

    GtkWidget *spacer = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_set_vexpand(spacer, TRUE);
    gtk_box_append(GTK_BOX(column), spacer);

    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    hud->footer_icon = gtk_image_new_from_icon_name("audio-input-microphone-symbolic");
    gtk_widget_add_css_class(hud->footer_icon, "footer-icon");
    hud->footer_spinner = gtk_spinner_new();
    hud->footer_label = gtk_label_new("");
    gtk_widget_add_css_class(hud->footer_label, "footer");
    gtk_label_set_xalign(GTK_LABEL(hud->footer_label), 0);
    gtk_label_set_ellipsize(GTK_LABEL(hud->footer_label), PANGO_ELLIPSIZE_END);
    gtk_widget_set_hexpand(hud->footer_label, TRUE);
    gtk_box_append(GTK_BOX(footer), hud->footer_icon);
    gtk_box_append(GTK_BOX(footer), hud->footer_spinner);
    gtk_box_append(GTK_BOX(footer), hud->footer_label);
    gtk_box_append(GTK_BOX(column), footer);

    hud->stage = TALKIES_HUD_IDLE;
    refresh_labels(hud);
    return hud;
}

void talkies_hud_destroy(TalkiesHud *hud) {
    if (!hud) return;
    if (hud->tick_id) gtk_widget_remove_tick_callback(hud->canvas, hud->tick_id);
    gtk_window_destroy(GTK_WINDOW(hud->window));
    g_free(hud->detail);
    g_free(hud->transcript);
    g_free(hud->hotkey_name);
    g_free(hud);
}

void talkies_hud_show(TalkiesHud *hud) {
    if (!hud || gtk_widget_get_visible(hud->window)) return;
    gtk_widget_set_visible(hud->window, TRUE);
    if (!hud->tick_id) hud->tick_id = gtk_widget_add_tick_callback(hud->canvas, on_tick, hud, NULL);
}

void talkies_hud_hide(TalkiesHud *hud) {
    if (!hud) return;
    if (hud->tick_id) {
        gtk_widget_remove_tick_callback(hud->canvas, hud->tick_id);
        hud->tick_id = 0;
    }
    gtk_widget_set_visible(hud->window, FALSE);
}

int talkies_hud_is_visible(TalkiesHud *hud) {
    return hud && gtk_widget_get_visible(hud->window);
}

void talkies_hud_set_stage(TalkiesHud *hud, TalkiesHudStage stage, const char *detail) {
    if (!hud) return;
    hud->stage = stage;
    g_free(hud->detail);
    hud->detail = detail ? g_strdup(detail) : NULL;
    if (stage != TALKIES_HUD_RECORDING) {
        hud->level = 0;
        hud->elapsed = 0;
    }
    refresh_labels(hud);
}

void talkies_hud_set_level(TalkiesHud *hud, float level) {
    if (!hud) return;
    hud->level = level < 0 ? 0 : (level > 1 ? 1 : level);
    // ±10% random variation per bar, refreshed with each level update.
    for (int i = 0; i < BAR_COUNT; i++) hud->jitter[i] = 0.9f + 0.2f * (float)g_random_double();
}

void talkies_hud_set_elapsed(TalkiesHud *hud, double seconds) {
    if (!hud) return;
    int changed = (int)seconds != (int)hud->elapsed;
    hud->elapsed = seconds;
    if (changed) refresh_labels(hud);
}

void talkies_hud_set_transcript(TalkiesHud *hud, const char *text) {
    if (!hud) return;
    g_free(hud->transcript);
    hud->transcript = text ? g_strdup(text) : NULL;
    refresh_labels(hud);
}

void talkies_hud_set_hotkey_name(TalkiesHud *hud, const char *name) {
    if (!hud) return;
    g_free(hud->hotkey_name);
    hud->hotkey_name = name ? g_strdup(name) : NULL;
    refresh_labels(hud);
}

void talkies_hud_set_record_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data) {
    if (!hud) return;
    hud->record_callback = callback;
    hud->record_user_data = user_data;
}
