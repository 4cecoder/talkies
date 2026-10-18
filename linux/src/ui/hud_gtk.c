#include "hud_gtk.h"
#include "loop_glib.h"

#include "gtk_compat.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef TALKIES_HAVE_X11
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk/x11/gdkx.h>
#endif

// Panel geometry, straight from DictationView.swift.
#define PILL_W 124.0
#define PILL_H 38.0
#define MAIN_W 560.0
#define MAIN_H 184.0
#define MINI_W 360.0
#define MINI_H 126.0
#define HISTORY_H 420.0
#define PANEL_RADIUS 24.0
#define SAMPLE_COUNT 160
// Unsaved (session-only) transcripts kept in memory.
#define HISTORY_LIMIT 50
// Rows asked of the daemon's store per page.
#define HISTORY_PAGE 50
// "Clear all" asks for a second click within this time.
#define CLEAR_CONFIRM_MS 3000
#define WIN_W TALKIES_HUD_WINDOW_WIDTH
#define WIN_H TALKIES_HUD_WINDOW_HEIGHT
// spring(response: 0.38, dampingFraction: 0.82)
#define SPRING_RESPONSE 0.38
#define SPRING_DAMPING 0.82
// Collapse this long after the pointer leaves a dismissable panel.
#define LEAVE_COLLAPSE_MS 450
#define COPY_RESET_MS 1600

typedef enum { PAGE_PILL, PAGE_MAIN, PAGE_MINI, PAGE_HISTORY } Page;

typedef struct {
    double r, g, b;
} Rgb;

typedef struct {
    double value, velocity, target;
} Spring;

typedef struct {
    gint64 id; // 0 = not saved (history saving off or unavailable)
    char *time;
    char *text;
} HistoryEntry;

typedef void (*LayerKeyboardFn)(GtkWindow *, int);

// One layout of the dictation controls (full and mini share this shape).
typedef struct {
    GtkWidget *root;
    GtkWidget *dot;
    GtkWidget *spinner;
    GtkWidget *status;
    GtkWidget *hint; // NULL in mini (hint sits in the footer)
    GtkWidget *history_button;
    GtkWidget *record_button;
    GtkWidget *waveform;
    GtkWidget *footer_icon; // NULL in mini
    GtkWidget *footer_label;
    GtkWidget *copy_button;
    GtkWidget *copy_icon;
    GtkWidget *copy_label;
    gboolean copied;
    guint copy_reset_id;
} Controls;

struct TalkiesHud {
    GtkWidget *window;
    GtkWidget *backdrop;
    GtkWidget *stack;
    GtkWidget *pill_waveform;
    Controls main;
    Controls mini;
    GtkWidget *history_page;
    GtkWidget *history_list;
    GtkWidget *history_empty;
    GtkWidget *history_search;
    GtkWidget *history_clear;
    GtkCssProvider *tint_css;

    TalkiesHudStage stage;
    char *detail;
    char *transcript;
    char *hotkey_name;
    char *attention_status;
    char *attention_hint;
    double elapsed;
    float samples[SAMPLE_COUNT];
    GPtrArray *history; // HistoryEntry* loaded from the store, newest first
    GPtrArray *session; // HistoryEntry* that were not saved, newest first
    gboolean history_more;
    gboolean clear_armed;
    guint clear_reset_id;

    gboolean expanded;
    gboolean mini_mode;
    gboolean show_history;
    Spring width, height;
    gint64 last_frame_us;
    gint64 start_us;
    guint tick_id;
    guint leave_id;
    gboolean pointer_inside;
    gboolean x11_positioned;
    // The history page takes keyboard focus (for search); dictation never does.
    gboolean wants_focus;
    LayerKeyboardFn layer_keyboard;

    TalkiesHudCallback record_callback;
    void *record_user_data;
    TalkiesHudCallback dismiss_callback;
    void *dismiss_user_data;
    TalkiesHudHistoryQueryFn history_query;
    TalkiesHudHistoryDeleteFn history_delete;
    TalkiesHudCallback history_clear_all;
    void *history_user_data;
};

// ---------------------------------------------------------------------------
// Stage presentation (PipelineStage on macOS, dark-mode system colours)
// ---------------------------------------------------------------------------

static const Rgb kGreen = {0.19, 0.82, 0.35};   // #30D158
static const Rgb kOrange = {1.0, 0.62, 0.04};   // #FF9F0A
static const Rgb kRed = {1.0, 0.27, 0.23};      // #FF453A
static const Rgb kPurple = {0.75, 0.35, 0.95};  // #BF5AF2
static const Rgb kBlue = {0.04, 0.52, 1.0};     // #0A84FF
static const Rgb kYellow = {1.0, 0.84, 0.04};   // #FFD60A
static const Rgb kCyan = {0.39, 0.82, 1.0};     // #64D2FF
static const Rgb kPink = {1.0, 0.22, 0.37};     // #FF375F
static const Rgb kMint = {0.39, 0.90, 0.89};    // #63E6E2

static gboolean stage_is_busy(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_LOADING_MODEL:
    case TALKIES_HUD_TRANSCRIBING:
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO:
    case TALKIES_HUD_INSERTING: return TRUE;
    default: return FALSE;
    }
}

// States the user may put away (macOS canCollapseFloatingWindow).
static gboolean stage_is_dismissable(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_IDLE:
    case TALKIES_HUD_COMPLETE:
    case TALKIES_HUD_CLEANUP_FALLBACK:
    case TALKIES_HUD_CLIPBOARD_FALLBACK:
    case TALKIES_HUD_NO_SPEECH:
    case TALKIES_HUD_ERROR: return TRUE;
    default: return FALSE;
    }
}

static Rgb stage_color(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_LOADING_MODEL:
    case TALKIES_HUD_TRANSCRIBING:
    case TALKIES_HUD_CLEANUP_FALLBACK:
    case TALKIES_HUD_CLIPBOARD_FALLBACK:
    case TALKIES_HUD_NO_SPEECH: return kOrange;
    case TALKIES_HUD_RECORDING:
    case TALKIES_HUD_ERROR: return kRed;
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return kPurple;
    case TALKIES_HUD_INSERTING: return kBlue;
    case TALKIES_HUD_COMPLETE: return kGreen;
    case TALKIES_HUD_IDLE:
    default: return hud->attention_status ? kOrange : kGreen;
    }
}

static const char *stage_icon(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_LOADING_MODEL: return "folder-download-symbolic";
    case TALKIES_HUD_RECORDING: return "audio-input-microphone-symbolic";
    case TALKIES_HUD_TRANSCRIBING:
    case TALKIES_HUD_NO_SPEECH: return "audio-x-generic-symbolic";
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return "starred-symbolic";
    case TALKIES_HUD_CLEANUP_FALLBACK: return "text-x-generic-symbolic";
    case TALKIES_HUD_INSERTING: return "insert-text-symbolic";
    case TALKIES_HUD_CLIPBOARD_FALLBACK: return "edit-paste-symbolic";
    case TALKIES_HUD_ERROR: return "dialog-warning-symbolic";
    case TALKIES_HUD_COMPLETE:
    case TALKIES_HUD_IDLE:
    default: return "object-select-symbolic";
    }
}

// PipelineStage.displayText
static const char *stage_display_text(TalkiesHudStage stage) {
    switch (stage) {
    case TALKIES_HUD_LOADING_MODEL: return "Loading speech model...";
    case TALKIES_HUD_RECORDING: return "Recording...";
    case TALKIES_HUD_TRANSCRIBING: return "Transcribing...";
    case TALKIES_HUD_CLEANING: return "Cleaning with S1-mini...";
    case TALKIES_HUD_ENHANCING_OLLAMA: return "Enhancing with Ollama...";
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return "Enhancing with LM Studio...";
    case TALKIES_HUD_INSERTING: return "Inserting text...";
    case TALKIES_HUD_COMPLETE: return "Complete";
    case TALKIES_HUD_ERROR: return "Error";
    case TALKIES_HUD_NO_SPEECH: return "No speech detected";
    case TALKIES_HUD_CLEANUP_FALLBACK: return "Using the raw transcript";
    case TALKIES_HUD_CLIPBOARD_FALLBACK: return "Manual paste needed";
    case TALKIES_HUD_IDLE:
    default: return "Ready";
    }
}

static const char *hotkey(const TalkiesHud *hud) {
    return hud->hotkey_name && hud->hotkey_name[0] ? hud->hotkey_name : "the hotkey";
}

static gboolean has_text(const char *s) {
    return s && s[0];
}

// MainDictationContent.statusText
static char *status_text(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_LOADING_MODEL: return g_strdup("Loading the local speech model");
    case TALKIES_HUD_RECORDING: {
        int total = (int)hud->elapsed;
        return g_strdup_printf("Recording · %02d:%02d", total / 60, total % 60);
    }
    case TALKIES_HUD_TRANSCRIBING: return g_strdup("Transcribing");
    case TALKIES_HUD_CLEANING: return g_strdup("Cleaning with S1-mini...");
    case TALKIES_HUD_ENHANCING_OLLAMA: return g_strdup("Enhancing with Ollama...");
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return g_strdup("Enhancing with LM Studio...");
    case TALKIES_HUD_INSERTING: return g_strdup("Inserting text...");
    case TALKIES_HUD_COMPLETE: return g_strdup("Text insertion complete");
    case TALKIES_HUD_CLIPBOARD_FALLBACK: return g_strdup("Copy transcript to paste manually");
    case TALKIES_HUD_NO_SPEECH: return g_strdup("No speech detected");
    case TALKIES_HUD_CLEANUP_FALLBACK: return g_strdup("Cleanup unavailable · using your raw transcript");
    case TALKIES_HUD_ERROR: return g_strdup_printf("Error: %s", has_text(hud->detail) ? hud->detail : "unknown");
    case TALKIES_HUD_IDLE:
    default: return g_strdup(hud->attention_status ? hud->attention_status : "Ready to dictate");
    }
}

// MainDictationContent.statusHint
static char *status_hint(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_LOADING_MODEL:
        return g_strdup("Preparing the on-device recognizer. This can take a moment the first time.");
    case TALKIES_HUD_RECORDING: return g_strdup("Speak naturally · audio stays on this computer");
    case TALKIES_HUD_TRANSCRIBING:
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return g_strdup("Processing locally on this computer");
    case TALKIES_HUD_INSERTING: return g_strdup("Typing into the focused app");
    case TALKIES_HUD_COMPLETE:
        return g_strdup(has_text(hud->detail) ? hud->detail
                                              : "If it did not appear in the target field, choose Copy and press Ctrl+V.");
    case TALKIES_HUD_CLIPBOARD_FALLBACK:
        return g_strdup(has_text(hud->detail) ? hud->detail : "Press Ctrl+V in the target field.");
    case TALKIES_HUD_NO_SPEECH: return g_strdup("Try a longer phrase and speak toward your selected microphone.");
    case TALKIES_HUD_CLEANUP_FALLBACK: return g_strdup("The original words will be used.");
    case TALKIES_HUD_ERROR: return g_strdup(has_text(hud->detail) ? hud->detail : "");
    case TALKIES_HUD_IDLE:
    default:
        if (hud->attention_status) return g_strdup(hud->attention_hint ? hud->attention_hint : "");
        return g_strdup_printf("Hold %s or click the microphone", hotkey(hud));
    }
}

// MainDictationContent.bottomStatusText
static char *footer_text(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_COMPLETE:
    case TALKIES_HUD_CLIPBOARD_FALLBACK: return g_strdup(hud->transcript ? hud->transcript : "");
    case TALKIES_HUD_ERROR: return g_strdup(has_text(hud->detail) ? hud->detail : "Something went wrong");
    case TALKIES_HUD_NO_SPEECH: return g_strdup("Speak clearly and try again.");
    case TALKIES_HUD_CLEANUP_FALLBACK:
        return g_strdup(has_text(hud->detail) ? hud->detail : "Using the uncleaned transcript.");
    default: return g_strdup(stage_display_text(hud->stage));
    }
}

// MiniDictationContent.miniHint
static char *mini_hint(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_IDLE:
        if (hud->attention_status) return g_strdup(hud->attention_hint ? hud->attention_hint : hud->attention_status);
        return g_strdup_printf("Hold %s to dictate", hotkey(hud));
    case TALKIES_HUD_CLIPBOARD_FALLBACK:
    case TALKIES_HUD_ERROR:
        return g_strdup(has_text(hud->detail) ? hud->detail : stage_display_text(hud->stage));
    case TALKIES_HUD_NO_SPEECH: return g_strdup("Try a longer phrase and speak toward your microphone.");
    case TALKIES_HUD_TRANSCRIBING: return g_strdup("Processing locally on this computer");
    case TALKIES_HUD_CLEANUP_FALLBACK: return g_strdup("The original words will be used.");
    case TALKIES_HUD_COMPLETE: return g_strdup("Text inserted · Copy if it didn’t appear");
    default: return g_strdup("");
    }
}

static gboolean can_copy(const TalkiesHud *hud) {
    switch (hud->stage) {
    case TALKIES_HUD_COMPLETE:
    case TALKIES_HUD_CLEANUP_FALLBACK:
    case TALKIES_HUD_CLIPBOARD_FALLBACK: return has_text(hud->transcript);
    default: return FALSE;
    }
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

static Page current_page(const TalkiesHud *hud) {
    if (!hud->expanded) return PAGE_PILL;
    if (hud->show_history) return PAGE_HISTORY;
    return hud->mini_mode ? PAGE_MINI : PAGE_MAIN;
}

static void target_size(const TalkiesHud *hud, double *w, double *h) {
    switch (current_page(hud)) {
    case PAGE_PILL: *w = PILL_W; *h = PILL_H; break;
    case PAGE_MINI: *w = MINI_W; *h = MINI_H; break;
    case PAGE_HISTORY: *w = hud->mini_mode ? MINI_W : MAIN_W; *h = HISTORY_H; break;
    case PAGE_MAIN:
    default: *w = MAIN_W; *h = MAIN_H; break;
    }
}

// The panel as currently drawn (animated), in window coordinates.
static void panel_rect(const TalkiesHud *hud, double *x, double *y, double *w, double *h) {
    *w = hud->width.value;
    *h = hud->height.value;
    *x = (WIN_W - *w) / 2.0;
    *y = TALKIES_HUD_PANEL_TOP;
}

static gboolean spring_step(Spring *s, double dt) {
    const double omega = 2.0 * G_PI / SPRING_RESPONSE;
    const double accel = -omega * omega * (s->value - s->target) - 2.0 * SPRING_DAMPING * omega * s->velocity;
    s->velocity += accel * dt;
    s->value += s->velocity * dt;
    if (fabs(s->value - s->target) < 0.25 && fabs(s->velocity) < 2.0) {
        s->value = s->target;
        s->velocity = 0;
        return FALSE;
    }
    return TRUE;
}

static void update_input_region(TalkiesHud *hud) {
    GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(hud->window));
    if (!surface) return;
    double x, y, w, h;
    panel_rect(hud, &x, &y, &w, &h);
    cairo_rectangle_int_t rect = {(int)floor(x), (int)floor(y), (int)ceil(w), (int)ceil(h)};
    cairo_region_t *region = cairo_region_create_rectangle(&rect);
    gdk_surface_set_input_region(surface, region);
    cairo_region_destroy(region);
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

static void rounded_rect(cairo_t *cr, double x, double y, double w, double h, double r) {
    if (r > h / 2) r = h / 2;
    if (r > w / 2) r = w / 2;
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - r, y + r, r, -G_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, G_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, G_PI / 2, G_PI);
    cairo_arc(cr, x + r, y + r, r, G_PI, 3 * G_PI / 2);
    cairo_close_path(cr);
}

// Panel chrome: shadow, tinted glass, violet glow, sheen and hairline stroke.
static void draw_backdrop(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer user_data) {
    (void)area;
    (void)width;
    (void)height;
    TalkiesHud *hud = user_data;
    double x, y, w, h;
    panel_rect(hud, &x, &y, &w, &h);
    const double radius = MIN(PANEL_RADIUS, h / 2);

    // shadow(color: .black.opacity(0.34), radius: 28, y: 14), approximated
    // with stacked translucent outlines.
    for (int i = 10; i >= 1; i--) {
        double spread = i * 2.4;
        rounded_rect(cr, x - spread / 2, y + 10 - spread / 4, w + spread, h + spread / 2, radius + spread / 2);
        cairo_set_source_rgba(cr, 0, 0, 0, 0.034 * (11 - i) / 10.0);
        cairo_fill(cr);
    }

    rounded_rect(cr, x, y, w, h, radius);
    cairo_save(cr);
    cairo_clip_preserve(cr);
    // Fill #0E0E16; more opaque than macOS's 0.58 since nothing blurs behind it.
    cairo_set_source_rgba(cr, 0.055, 0.055, 0.085, 0.86);
    cairo_fill(cr);
    // Liquid Glass tint #6E4FEB @ 0.18.
    cairo_set_source_rgba(cr, 0.43, 0.31, 0.92, 0.10);
    cairo_paint(cr);

    // Violet glow: 220x150 ellipse #754DF2 @ 0.18, blur 38, offset (-190, -75)
    // from the panel centre.
    double gx = x + w / 2 - 190 * (w / MAIN_W), gy = y + h / 2 - 75 * (h / MAIN_H);
    cairo_save(cr);
    cairo_translate(cr, gx, gy);
    cairo_scale(cr, 1.0, 150.0 / 220.0);
    cairo_pattern_t *glow = cairo_pattern_create_radial(0, 0, 0, 0, 0, 110 + 38);
    cairo_pattern_add_color_stop_rgba(glow, 0, 0.46, 0.30, 0.95, 0.18);
    cairo_pattern_add_color_stop_rgba(glow, 0.55, 0.46, 0.30, 0.95, 0.12);
    cairo_pattern_add_color_stop_rgba(glow, 1, 0.46, 0.30, 0.95, 0);
    cairo_set_source(cr, glow);
    cairo_paint(cr);
    cairo_pattern_destroy(glow);
    cairo_restore(cr);

    // Sheen: white @ 0.035 -> clear -> black @ 0.12, top-leading to bottom-trailing.
    cairo_pattern_t *sheen = cairo_pattern_create_linear(x, y, x + w, y + h);
    cairo_pattern_add_color_stop_rgba(sheen, 0, 1, 1, 1, 0.035);
    cairo_pattern_add_color_stop_rgba(sheen, 0.5, 1, 1, 1, 0);
    cairo_pattern_add_color_stop_rgba(sheen, 1, 0, 0, 0, 0.12);
    cairo_set_source(cr, sheen);
    cairo_paint(cr);
    cairo_pattern_destroy(sheen);
    cairo_restore(cr);

    rounded_rect(cr, x + 0.5, y + 0.5, w - 1, h - 1, radius - 0.5);
    cairo_set_source_rgba(cr, 1, 1, 1, 0.13);
    cairo_set_line_width(cr, 1.0);
    cairo_stroke(cr);
}

static void draw_dot(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer user_data) {
    (void)area;
    TalkiesHud *hud = user_data;
    Rgb c = stage_color(hud);
    double cx = width / 2.0, cy = height / 2.0;
    double r = width >= 18 ? 4.0 : 3.5; // 8pt dot (mini: 7pt)
    // .shadow(color: statusColor.opacity(0.5), radius: 5)
    cairo_pattern_t *glow = cairo_pattern_create_radial(cx, cy, r * 0.5, cx, cy, r + 5);
    cairo_pattern_add_color_stop_rgba(glow, 0, c.r, c.g, c.b, 0.5);
    cairo_pattern_add_color_stop_rgba(glow, 1, c.r, c.g, c.b, 0);
    cairo_set_source(cr, glow);
    cairo_paint(cr);
    cairo_pattern_destroy(glow);
    cairo_set_source_rgb(cr, c.r, c.g, c.b);
    cairo_arc(cr, cx, cy, r, 0, 2 * G_PI);
    cairo_fill(cr);
}

static void waveform_palette(const TalkiesHud *hud, Rgb *colors, int *count) {
    if (hud->stage == TALKIES_HUD_RECORDING) {
        colors[0] = (Rgb){1.0, 0.35, 0.49};
        colors[1] = (Rgb){1.0, 0.63, 0.47};
        colors[2] = (Rgb){0.72, 0.51, 1.0};
        *count = 3;
        return;
    }
    *count = 2;
    switch (hud->stage) {
    case TALKIES_HUD_LOADING_MODEL: colors[0] = kBlue; colors[1] = kCyan; break;
    case TALKIES_HUD_TRANSCRIBING: colors[0] = kOrange; colors[1] = kYellow; break;
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: colors[0] = kPurple; colors[1] = kPink; break;
    case TALKIES_HUD_INSERTING: colors[0] = kCyan; colors[1] = kBlue; break;
    case TALKIES_HUD_COMPLETE: colors[0] = kGreen; colors[1] = kMint; break;
    case TALKIES_HUD_ERROR: colors[0] = kRed; colors[1] = kOrange; break;
    case TALKIES_HUD_CLIPBOARD_FALLBACK:
    case TALKIES_HUD_CLEANUP_FALLBACK:
    case TALKIES_HUD_NO_SPEECH: colors[0] = kOrange; colors[1] = kYellow; break;
    case TALKIES_HUD_IDLE:
    default: colors[0] = kPurple; colors[1] = kCyan; break;
    }
}

// WaveformView.stateLevel
static double state_level(TalkiesHudStage stage, double pos, double ph) {
    switch (stage) {
    case TALKIES_HUD_LOADING_MODEL: return 0.12 + 0.22 * (0.5 + 0.5 * sin(ph * 2.2 + pos * 3));
    case TALKIES_HUD_TRANSCRIBING: {
        double sweep = fabs(pos - fmod(ph * 0.24, 1.0));
        return 0.12 + 0.62 * exp(-sweep * 11);
    }
    case TALKIES_HUD_CLEANING:
    case TALKIES_HUD_ENHANCING_OLLAMA:
    case TALKIES_HUD_ENHANCING_LM_STUDIO: return 0.10 + 0.58 * fabs(sin(pos * 11 - ph * 3.1));
    case TALKIES_HUD_INSERTING: {
        double sweep = fabs(pos - fmod(ph * 0.6, 1.0));
        return 0.12 + 0.74 * exp(-sweep * 15);
    }
    case TALKIES_HUD_COMPLETE: return 0.10 + 0.28 * fabs(sin(pos * 8));
    case TALKIES_HUD_ERROR: return 0.08 + 0.14 * (0.5 + 0.5 * sin(ph * 1.8));
    default: return 0.08;
    }
}

static double recording_height(const TalkiesHud *hud, int index, double max_h) {
    // set_level() receives the daemon's -60..0 dB meter value already. Keep
    // that scale intact and use a gentle display curve: applying a second
    // threshold/normalization here made ordinary speech fill most of the HUD.
    const double level = isfinite(hud->samples[index])
        ? CLAMP(hud->samples[index], 0.0, 1.0)
        : 0.0;
    return MAX(2.5, pow(level, 1.2) * max_h);
}

static void append_wave_curve(cairo_t *cr, double x0, double y0, double before_y,
                              double x1, double y1, double after_y) {
    const double dx = x1 - x0;
    const double low = MIN(y0, y1);
    const double high = MAX(y0, y1);
    // Catmull-Rom tangents converted to Bezier handles. Constraining the
    // handles to their segment keeps quiet gaps from ringing below the floor.
    const double c1 = CLAMP(y0 + (y1 - before_y) / 6.0, low, high);
    const double c2 = CLAMP(y1 - (after_y - y0) / 6.0, low, high);
    cairo_curve_to(cr, x0 + dx / 3.0, c1, x1 - dx / 3.0, c2, x1, y1);
}

static void draw_recording_waveform(TalkiesHud *hud, cairo_t *cr, int width,
                                    double center, double max_h,
                                    const Rgb *colors, int ncolors) {
    const double step = (double)width / (SAMPLE_COUNT - 1);
    double height = recording_height(hud, 0, max_h);
    cairo_move_to(cr, 0, center - height / 2.0);

    for (int i = 0; i < SAMPLE_COUNT - 1; i++) {
        const int before = MAX(0, i - 1);
        const int after = MIN(SAMPLE_COUNT - 1, i + 2);
        const double y0 = center - recording_height(hud, i, max_h) / 2.0;
        const double y1 = center - recording_height(hud, i + 1, max_h) / 2.0;
        const double before_y = center - recording_height(hud, before, max_h) / 2.0;
        const double after_y = center - recording_height(hud, after, max_h) / 2.0;
        append_wave_curve(cr, i * step, y0, before_y, (i + 1) * step, y1, after_y);
    }

    height = recording_height(hud, SAMPLE_COUNT - 1, max_h);
    cairo_line_to(cr, width, center + height / 2.0);
    for (int i = SAMPLE_COUNT - 1; i > 0; i--) {
        const int before = MIN(SAMPLE_COUNT - 1, i + 1);
        const int after = MAX(0, i - 2);
        const double y0 = center + recording_height(hud, i, max_h) / 2.0;
        const double y1 = center + recording_height(hud, i - 1, max_h) / 2.0;
        const double before_y = center + recording_height(hud, before, max_h) / 2.0;
        const double after_y = center + recording_height(hud, after, max_h) / 2.0;
        append_wave_curve(cr, i * step, y0, before_y, (i - 1) * step, y1, after_y);
    }
    cairo_close_path(cr);

    cairo_pattern_t *gradient = cairo_pattern_create_linear(0, center, width, center);
    for (int i = 0; i < ncolors; i++) {
        cairo_pattern_add_color_stop_rgba(gradient, (double)i / (ncolors - 1),
                                          colors[i].r, colors[i].g, colors[i].b, 0.92);
    }
    cairo_set_source(cr, gradient);
    cairo_fill_preserve(cr);
    cairo_pattern_destroy(gradient);

    cairo_set_source_rgba(cr, 1.0, 0.88, 0.96, 0.28);
    cairo_set_line_width(cr, 0.8);
    cairo_stroke(cr);
}

static void draw_waveform(GtkDrawingArea *area, cairo_t *cr, int width, int height, gpointer user_data) {
    (void)area;
    TalkiesHud *hud = user_data;
    if (width <= 0 || height <= 0) return;
    const gboolean recording = hud->stage == TALKIES_HUD_RECORDING;
    // The phase only advances while the stage animates (TimelineView paused).
    const double ph = stage_is_busy(hud->stage) ? (g_get_monotonic_time() - hud->start_us) / 1e6 : 0.0;

    const int bars = MAX(1, width / 3);
    const double gap = 1.1;
    const double bar_w = MAX(1.0, (width - (bars - 1) * gap) / bars);
    const double center = height / 2.0;
    const double max_h = height * 0.88;

    Rgb colors[3];
    int ncolors;
    waveform_palette(hud, colors, &ncolors);
    const double opacity = recording ? 0.96 : 0.82;

    if (recording) {
        draw_recording_waveform(hud, cr, width, center, max_h, colors, ncolors);
        return;
    }

    for (int i = 0; i < bars; i++) {
        double pos = (double)i / MAX(bars - 1, 1);
        double peak;
        peak = state_level(hud->stage, pos, ph);
        double normalized = CLAMP((peak - 0.035) / 0.965, 0.0, 1.0);
        double bar_h = MAX(2.5, pow(normalized, 0.82) * max_h);
        double x = i * (bar_w + gap);
        double top = center - bar_h / 2;

        cairo_pattern_t *grad = cairo_pattern_create_linear(x, top, x, top + bar_h);
        for (int c = 0; c < ncolors; c++) {
            cairo_pattern_add_color_stop_rgba(grad, (double)c / (ncolors - 1), colors[c].r, colors[c].g, colors[c].b, opacity);
        }
        rounded_rect(cr, x, top, bar_w, bar_h, bar_w / 2);
        cairo_set_source(cr, grad);
        cairo_fill(cr);
        cairo_pattern_destroy(grad);
    }
}

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------

static void refresh_tint(TalkiesHud *hud) {
    Rgb c = stage_color(hud);
    char css[256];
    g_snprintf(css, sizeof css, ".talkies-hud .stage-tint { color: rgb(%d,%d,%d); }", (int)(c.r * 255), (int)(c.g * 255),
               (int)(c.b * 255));
    gtk_css_provider_load_from_string(hud->tint_css, css);
}

static void refresh_copy(Controls *c, gboolean mini) {
    gtk_image_set_from_icon_name(GTK_IMAGE(c->copy_icon), c->copied ? "object-select-symbolic" : "edit-copy-symbolic");
    gtk_label_set_text(GTK_LABEL(c->copy_label), c->copied ? "Copied" : (mini ? "Copy" : "Copy text"));
    if (c->copied) {
        gtk_widget_add_css_class(c->copy_button, "copied");
    } else {
        gtk_widget_remove_css_class(c->copy_button, "copied");
    }
    gtk_widget_set_tooltip_text(c->copy_button, c->copied ? "Transcript copied. Press Ctrl+V in the target field."
                                                          : "Copy transcript to clipboard");
}

static void refresh_controls(TalkiesHud *hud, Controls *c, gboolean mini) {
    const gboolean busy = stage_is_busy(hud->stage);
    const gboolean recording = hud->stage == TALKIES_HUD_RECORDING;

    char *status = status_text(hud);
    gtk_label_set_text(GTK_LABEL(c->status), status);
    g_free(status);
    gtk_widget_set_visible(c->spinner, busy);
    gtk_spinner_set_spinning(GTK_SPINNER(c->spinner), busy);

    gtk_button_set_icon_name(GTK_BUTTON(c->record_button),
                             recording ? "media-playback-stop-symbolic" : "audio-input-microphone-symbolic");
    gtk_widget_set_tooltip_text(c->record_button, recording ? "Stop dictation" : "Start dictation");
    if (recording) {
        gtk_widget_add_css_class(c->record_button, "recording");
    } else {
        gtk_widget_remove_css_class(c->record_button, "recording");
    }

    if (mini) {
        char *hint = mini_hint(hud);
        gtk_label_set_text(GTK_LABEL(c->footer_label), hint);
        g_free(hint);
    } else {
        char *hint = status_hint(hud);
        gtk_label_set_text(GTK_LABEL(c->hint), hint);
        gtk_widget_set_visible(c->hint, hint[0] != '\0');
        g_free(hint);

        gboolean pipeline = hud->stage != TALKIES_HUD_IDLE && hud->stage != TALKIES_HUD_RECORDING;
        char *footer;
        gtk_widget_remove_css_class(c->footer_label, "muted");
        gtk_widget_remove_css_class(c->footer_label, "transcript");
        if (pipeline) {
            footer = footer_text(hud);
        } else if (has_text(hud->transcript)) {
            footer = g_strdup(hud->transcript);
            gtk_widget_add_css_class(c->footer_label, "transcript");
        } else {
            footer = hud->attention_status ? g_strdup("Fix the item above in Settings to start dictating")
                                           : g_strdup_printf("Hold %s for push-to-talk", hotkey(hud));
            gtk_widget_add_css_class(c->footer_label, "muted");
        }
        // Single line, like .lineLimit(1).
        g_strdelimit(footer, "\n\r", ' ');
        gtk_label_set_text(GTK_LABEL(c->footer_label), footer);
        g_free(footer);
        gtk_image_set_from_icon_name(GTK_IMAGE(c->footer_icon), stage_icon(hud->stage));
        gtk_widget_set_visible(c->footer_icon, pipeline);
    }
    gtk_widget_set_visible(c->copy_button, can_copy(hud));
    refresh_copy(c, mini);
    gtk_widget_queue_draw(c->dot);
    gtk_widget_queue_draw(c->waveform);
}

static void refresh(TalkiesHud *hud) {
    refresh_tint(hud);
    refresh_controls(hud, &hud->main, FALSE);
    refresh_controls(hud, &hud->mini, TRUE);
    gtk_widget_set_tooltip_text(hud->pill_waveform, "Open Talkies dictation");
    gtk_widget_queue_draw(hud->pill_waveform);
}

// ---------------------------------------------------------------------------
// Animation
// ---------------------------------------------------------------------------

static gboolean needs_frames(const TalkiesHud *hud) {
    return hud->width.value != hud->width.target || hud->height.value != hud->height.target ||
           hud->width.velocity != 0 || hud->height.velocity != 0 || stage_is_busy(hud->stage) ||
           hud->stage == TALKIES_HUD_RECORDING;
}

static gboolean on_tick(GtkWidget *widget, GdkFrameClock *clock, gpointer user_data) {
    (void)widget;
    TalkiesHud *hud = user_data;
    gint64 now = gdk_frame_clock_get_frame_time(clock);
    double dt = hud->last_frame_us ? (now - hud->last_frame_us) / 1e6 : 1.0 / 60.0;
    hud->last_frame_us = now;
    dt = CLAMP(dt, 0.0, 1.0 / 20.0);

    gboolean animating = hud->width.value != hud->width.target || hud->height.value != hud->height.target ||
                         hud->width.velocity != 0 || hud->height.velocity != 0;
    if (animating) {
        spring_step(&hud->width, dt);
        spring_step(&hud->height, dt);
        gtk_widget_queue_draw(hud->backdrop);
        update_input_region(hud);
    }

    // Waveforms are capped near 30 fps, as on macOS.
    static gint64 last_wave_us = 0;
    if (now - last_wave_us >= 33000) {
        last_wave_us = now;
        if (stage_is_busy(hud->stage) || hud->stage == TALKIES_HUD_RECORDING) {
            Page page = current_page(hud);
            if (page == PAGE_PILL) gtk_widget_queue_draw(hud->pill_waveform);
            if (page == PAGE_MAIN) gtk_widget_queue_draw(hud->main.waveform);
            if (page == PAGE_MINI) gtk_widget_queue_draw(hud->mini.waveform);
        }
    }

    if (!needs_frames(hud)) {
        hud->tick_id = 0;
        hud->last_frame_us = 0;
        return G_SOURCE_REMOVE;
    }
    return G_SOURCE_CONTINUE;
}

static void ensure_ticking(TalkiesHud *hud) {
    if (!hud->tick_id && gtk_widget_get_visible(hud->window) && needs_frames(hud)) {
        hud->last_frame_us = 0;
        hud->tick_id = gtk_widget_add_tick_callback(hud->backdrop, on_tick, hud, NULL);
    }
}

static const char *page_name(Page page) {
    switch (page) {
    case PAGE_PILL: return "pill";
    case PAGE_MINI: return "mini";
    case PAGE_HISTORY: return "history";
    case PAGE_MAIN:
    default: return "main";
    }
}

static void apply_focus(TalkiesHud *hud);

static void apply_layout(TalkiesHud *hud) {
    double w, h;
    target_size(hud, &w, &h);
    hud->width.target = w;
    hud->height.target = h;
    gtk_widget_set_size_request(hud->history_page, hud->mini_mode ? (int)MINI_W : (int)MAIN_W, (int)HISTORY_H);
    gtk_stack_set_visible_child_name(GTK_STACK(hud->stack), page_name(current_page(hud)));
    gboolean history = current_page(hud) == PAGE_HISTORY;
    if (history != hud->wants_focus) {
        hud->wants_focus = history;
        apply_focus(hud);
    }
    ensure_ticking(hud);
}

static void cancel_leave(TalkiesHud *hud) {
    if (hud->leave_id) {
        g_source_remove(hud->leave_id);
        hud->leave_id = 0;
    }
}

static void collapse_by_user(TalkiesHud *hud) {
    if (!hud->expanded || !stage_is_dismissable(hud->stage)) return;
    hud->show_history = FALSE;
    talkies_hud_set_expanded(hud, FALSE);
    if (hud->dismiss_callback) hud->dismiss_callback(hud->dismiss_user_data);
}

static gboolean on_leave_timeout(gpointer user_data) {
    TalkiesHud *hud = user_data;
    hud->leave_id = 0;
    if (!hud->pointer_inside) collapse_by_user(hud);
    return G_SOURCE_REMOVE;
}

static void on_pointer_enter(GtkEventControllerMotion *motion, double x, double y, gpointer user_data) {
    (void)motion;
    (void)x;
    (void)y;
    TalkiesHud *hud = user_data;
    hud->pointer_inside = TRUE;
    cancel_leave(hud);
}

static void on_pointer_leave(GtkEventControllerMotion *motion, gpointer user_data) {
    (void)motion;
    TalkiesHud *hud = user_data;
    hud->pointer_inside = FALSE;
    cancel_leave(hud);
    if (hud->expanded && stage_is_dismissable(hud->stage)) {
        hud->leave_id = g_timeout_add(LEAVE_COLLAPSE_MS, on_leave_timeout, hud);
    }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

static void on_record_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    if (hud->record_callback) hud->record_callback(hud->record_user_data);
}

static void history_reload(TalkiesHud *hud);

static void on_history_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    hud->show_history = TRUE;
    // Fresh from the store: `talkies history clear` may have run meanwhile.
    history_reload(hud);
    apply_layout(hud);
}

static void on_history_close(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    hud->show_history = FALSE;
    apply_layout(hud);
}

static void rebuild_history(TalkiesHud *hud);

static void history_entry_free(gpointer data) {
    HistoryEntry *entry = data;
    g_free(entry->time);
    g_free(entry->text);
    g_free(entry);
}

// Today: the time; otherwise the date too.
static char *history_time(gint64 created_ms) {
    GDateTime *when = g_date_time_new_from_unix_local(created_ms / 1000);
    if (!when) return g_strdup("");
    GDateTime *now = g_date_time_new_now_local();
    const char *format = "%Y-%m-%d %H:%M";
    if (g_date_time_get_year(when) == g_date_time_get_year(now)) {
        format = g_date_time_get_day_of_year(when) == g_date_time_get_day_of_year(now) ? "%H:%M:%S" : "%b %e, %H:%M";
    }
    char *text = g_date_time_format(when, format);
    g_date_time_unref(now);
    g_date_time_unref(when);
    return text ? text : g_strdup("");
}

static HistoryEntry *history_entry_new(gint64 id, gint64 created_ms, const char *text) {
    HistoryEntry *entry = g_malloc0(sizeof *entry);
    entry->id = id;
    entry->time = history_time(created_ms);
    entry->text = g_strdup(text);
    return entry;
}

static const char *history_search_text(TalkiesHud *hud) {
    return gtk_editable_get_text(GTK_EDITABLE(hud->history_search));
}

// Same rule as the store's LIKE search, for entries that were never saved.
static gboolean history_matches(const char *text, const char *search) {
    if (!has_text(search)) return TRUE;
    char *haystack = g_utf8_casefold(text, -1);
    char *needle = g_utf8_casefold(search, -1);
    gboolean found = strstr(haystack, needle) != NULL;
    g_free(haystack);
    g_free(needle);
    return found;
}

// Ask the store for the first page of the current search.
static void history_reload(TalkiesHud *hud) {
    if (!hud->history_query) {
        rebuild_history(hud);
        return;
    }
    g_ptr_array_set_size(hud->history, 0);
    hud->history_more = FALSE;
    hud->history_query(history_search_text(hud), 0, HISTORY_PAGE, hud->history_user_data);
    rebuild_history(hud);
}

static void on_history_search(GtkSearchEntry *entry, gpointer user_data) {
    (void)entry;
    history_reload(user_data);
}

static void on_history_more(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    if (!hud->history_query) return;
    hud->history_more = FALSE;
    hud->history_query(history_search_text(hud), (int)hud->history->len, HISTORY_PAGE, hud->history_user_data);
    rebuild_history(hud);
}

static void on_history_copy(GtkButton *button, gpointer user_data) {
    TalkiesHud *hud = user_data;
    HistoryEntry *entry = g_object_get_data(G_OBJECT(button), "entry");
    if (!entry) return;
    gdk_clipboard_set_text(gtk_widget_get_clipboard(hud->window), entry->text);
    gtk_button_set_icon_name(button, "object-select-symbolic");
    gtk_widget_set_tooltip_text(GTK_WIDGET(button), "Copied");
}

static void on_history_delete(GtkButton *button, gpointer user_data) {
    TalkiesHud *hud = user_data;
    HistoryEntry *entry = g_object_get_data(G_OBJECT(button), "entry");
    if (!entry) return;
    guint index;
    if (g_ptr_array_find(hud->history, entry, &index)) {
        if (hud->history_delete) hud->history_delete(entry->id, hud->history_user_data);
        g_ptr_array_remove_index(hud->history, index);
    } else if (g_ptr_array_find(hud->session, entry, &index)) {
        g_ptr_array_remove_index(hud->session, index);
    }
    rebuild_history(hud);
}

static void history_disarm_clear(TalkiesHud *hud) {
    if (hud->clear_reset_id) g_source_remove(hud->clear_reset_id);
    hud->clear_reset_id = 0;
    hud->clear_armed = FALSE;
    gtk_button_set_label(GTK_BUTTON(hud->history_clear), "Clear all");
}

static gboolean on_clear_timeout(gpointer user_data) {
    TalkiesHud *hud = user_data;
    hud->clear_reset_id = 0;
    history_disarm_clear(hud);
    return G_SOURCE_REMOVE;
}

// History is kept until deleted, so clearing it takes a second click.
static void on_history_clear(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    if (!hud->clear_armed) {
        hud->clear_armed = TRUE;
        gtk_button_set_label(GTK_BUTTON(hud->history_clear), "Clear all?");
        hud->clear_reset_id = g_timeout_add(CLEAR_CONFIRM_MS, on_clear_timeout, hud);
        return;
    }
    history_disarm_clear(hud);
    if (hud->history_clear_all) hud->history_clear_all(hud->history_user_data);
    g_ptr_array_set_size(hud->history, 0);
    g_ptr_array_set_size(hud->session, 0);
    hud->history_more = FALSE;
    g_clear_pointer(&hud->transcript, g_free);
    rebuild_history(hud);
    refresh(hud);
}

static void on_pill_pressed(GtkGestureClick *gesture, int n_press, double x, double y, gpointer user_data) {
    (void)gesture;
    (void)n_press;
    (void)x;
    (void)y;
    talkies_hud_set_expanded(user_data, TRUE);
}

static gboolean reset_copy(gpointer user_data) {
    Controls *c = user_data;
    c->copy_reset_id = 0;
    c->copied = FALSE;
    refresh_copy(c, TRUE);
    return G_SOURCE_REMOVE;
}

static void copy_transcript(TalkiesHud *hud, Controls *c, gboolean mini) {
    if (!has_text(hud->transcript)) return;
    GdkClipboard *clipboard = gtk_widget_get_clipboard(hud->window);
    gdk_clipboard_set_text(clipboard, hud->transcript);
    c->copied = TRUE;
    refresh_copy(c, mini);
    // The mini panel resets its "Copied" badge; the full panel keeps it until
    // the next recording (as on macOS).
    if (mini) {
        if (c->copy_reset_id) g_source_remove(c->copy_reset_id);
        c->copy_reset_id = g_timeout_add(COPY_RESET_MS, reset_copy, c);
    }
}

static void on_copy_main(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    copy_transcript(hud, &hud->main, FALSE);
}

static void on_copy_mini(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesHud *hud = user_data;
    copy_transcript(hud, &hud->mini, TRUE);
}

// ---------------------------------------------------------------------------
// Placement
// ---------------------------------------------------------------------------

#ifdef TALKIES_HAVE_X11
// GTK4 dropped accept-focus/keep-above; set the equivalent X11 hints directly
// so the panel never steals keyboard focus from the app being dictated into,
// then anchor it at the top centre of the monitor under the pointer.
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
        hints->input = hud->wants_focus ? True : False;
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

    // Hyprland places XWayland windows by rule (see applyCompositorRules),
    // using the monitor's reserved area; an X11 move would fight it.
    if (g_getenv("HYPRLAND_INSTANCE_SIGNATURE")) {
        XFlush(xdpy);
        return;
    }

    GdkRectangle area = {0, 0, DisplayWidth(xdpy, DefaultScreen(xdpy)), DisplayHeight(xdpy, DefaultScreen(xdpy))};
    Window root_ret, child_ret;
    int px = 0, py = 0, wx, wy;
    unsigned int mask;
    XQueryPointer(xdpy, DefaultRootWindow(xdpy), &root_ret, &child_ret, &px, &py, &wx, &wy, &mask);
    GListModel *monitors = gdk_display_get_monitors(display);
    for (guint i = 0; i < g_list_model_get_n_items(monitors); i++) {
        GdkMonitor *monitor = g_list_model_get_item(monitors, i);
        GdkRectangle geometry;
        gdk_monitor_get_geometry(monitor, &geometry);
        g_object_unref(monitor);
        if (i == 0 || (px >= geometry.x && px < geometry.x + geometry.width && py >= geometry.y &&
                       py < geometry.y + geometry.height)) {
            area = geometry;
            if (i != 0) break;
        }
    }
    // Start below top panels: _NET_WORKAREA is the desktop minus struts.
    int top = area.y;
    Atom workarea = XInternAtom(xdpy, "_NET_WORKAREA", True);
    if (workarea != None) {
        Atom actual;
        int format;
        unsigned long count = 0, after;
        unsigned char *data = NULL;
        if (XGetWindowProperty(xdpy, DefaultRootWindow(xdpy), workarea, 0, 4, False, XA_CARDINAL, &actual, &format,
                               &count, &after, &data) == Success &&
            data && count >= 4 && format == 32) {
            long *wa = (long *)data;
            if (wa[1] > top && wa[1] < area.y + area.height / 2) top = (int)wa[1];
        }
        if (data) XFree(data);
    }
    XMoveWindow(xdpy, xid, area.x + (area.width - WIN_W) / 2, top + TALKIES_HUD_SCREEN_TOP - TALKIES_HUD_PANEL_TOP);
    XFlush(xdpy);
}
#endif

// Native Wayland without XWayland: use gtk4-layer-shell when it is installed
// (resolved at runtime so packages don't depend on it). Must run before the
// window is realized. Returns TRUE when the window became a layer surface.
static gboolean try_layer_shell(TalkiesHud *hud) {
    GtkWindow *window = GTK_WINDOW(hud->window);
#ifdef GDK_WINDOWING_WAYLAND
    // Check the display type by name: GDK_IS_WAYLAND_DISPLAY would link
    // gdk_wayland_display_get_type, which GTK builds without the Wayland
    // backend (e.g. Gentoo USE=-wayland) do not export, and the prebuilt
    // package would then fail to start.
    GdkDisplay *display = gdk_display_get_default();
    if (!display || g_strcmp0(G_OBJECT_TYPE_NAME(display), "GdkWaylandDisplay") != 0) return FALSE;
    void *lib = dlopen("libgtk4-layer-shell.so.0", RTLD_NOW | RTLD_GLOBAL);
    if (!lib) return FALSE;
    typedef gboolean (*IsSupported)(void);
    typedef void (*Init)(GtkWindow *);
    typedef void (*SetInt)(GtkWindow *, int);
    typedef void (*SetEdge)(GtkWindow *, int, gboolean);
    typedef void (*SetMargin)(GtkWindow *, int, int);
    typedef void (*SetNamespace)(GtkWindow *, const char *);
    IsSupported is_supported = (IsSupported)dlsym(lib, "gtk_layer_is_supported");
    Init init = (Init)dlsym(lib, "gtk_layer_init_for_window");
    SetInt set_layer = (SetInt)dlsym(lib, "gtk_layer_set_layer");
    SetEdge set_anchor = (SetEdge)dlsym(lib, "gtk_layer_set_anchor");
    SetMargin set_margin = (SetMargin)dlsym(lib, "gtk_layer_set_margin");
    SetInt set_keyboard = (SetInt)dlsym(lib, "gtk_layer_set_keyboard_mode");
    SetNamespace set_namespace = (SetNamespace)dlsym(lib, "gtk_layer_set_namespace");
    if (!init || !set_layer || !set_anchor || !set_margin || (is_supported && !is_supported())) return FALSE;
    init(window);
    set_layer(window, 3 /* GTK_LAYER_SHELL_LAYER_OVERLAY */);
    set_anchor(window, 2 /* GTK_LAYER_SHELL_EDGE_TOP */, TRUE);
    set_margin(window, 2, TALKIES_HUD_SCREEN_TOP - TALKIES_HUD_PANEL_TOP);
    if (set_keyboard) set_keyboard(window, 0 /* GTK_LAYER_SHELL_KEYBOARD_MODE_NONE */);
    hud->layer_keyboard = set_keyboard;
    if (set_namespace) set_namespace(window, "talkies");
    return TRUE;
#else
    (void)window;
    return FALSE;
#endif
}

// Typing a search needs keyboard focus, which the panel otherwise never takes
// so that dictation lands in the app underneath. Only the history page asks
// for it: an X11 input hint, or on-demand keyboard for a layer surface.
// (Compositors that force no-focus by rule, like the Hyprland rules, keep it.)
static void apply_focus(TalkiesHud *hud) {
    if (hud->layer_keyboard) {
        hud->layer_keyboard(GTK_WINDOW(hud->window), hud->wants_focus ? 2 /* ON_DEMAND */ : 0 /* NONE */);
    }
#ifdef TALKIES_HAVE_X11
    GdkDisplay *display = gtk_widget_get_display(hud->window);
    GdkSurface *surface = gtk_native_get_surface(GTK_NATIVE(hud->window));
    if (surface && GDK_IS_X11_DISPLAY(display)) {
        Display *xdpy = gdk_x11_display_get_xdisplay(display);
        XWMHints *hints = XAllocWMHints();
        if (hints) {
            hints->flags = InputHint;
            hints->input = hud->wants_focus ? True : False;
            XSetWMHints(xdpy, gdk_x11_surface_get_xid(surface), hints);
            XFree(hints);
            XFlush(xdpy);
        }
    }
#endif
    if (!hud->wants_focus) gtk_window_set_focus(GTK_WINDOW(hud->window), NULL);
}

static void on_realize(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    TalkiesHud *hud = user_data;
#ifdef TALKIES_HAVE_X11
    apply_x11_hints(hud);
#endif
    update_input_region(hud);
}

static void on_map(GtkWidget *widget, gpointer user_data) {
    (void)widget;
    TalkiesHud *hud = user_data;
#ifdef TALKIES_HAVE_X11
    // Re-anchor on every show so the panel follows the active monitor.
    apply_x11_hints(hud);
#endif
    update_input_region(hud);
}

static gboolean on_close_request(GtkWindow *window, gpointer user_data) {
    (void)user_data;
    gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
    return TRUE;
}

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

static const char *hud_css =
    "window.talkies-hud, window.talkies-hud > * { background: transparent; box-shadow: none; }"
    ".talkies-hud label { color: white; }"
    ".talkies-hud .status { font-size: 13px; font-weight: 600; }"
    ".talkies-hud .mini .status { font-size: 12px; }"
    ".talkies-hud .hint { font-size: 11px; color: rgba(255,255,255,0.62); }"
    ".talkies-hud .mini .hint { font-size: 10px; font-weight: 500; }"
    ".talkies-hud .footer { font-size: 11px; font-weight: 500; color: rgba(255,255,255,0.78); }"
    ".talkies-hud .footer.transcript { font-weight: 400; color: rgba(255,255,255,0.72); }"
    ".talkies-hud .footer.muted { font-weight: 400; color: rgba(255,255,255,0.5); }"
    ".talkies-hud .footer-icon { -gtk-icon-size: 11px; }"
    ".talkies-hud spinner { min-width: 13px; min-height: 13px; }"
    ".talkies-hud .mini spinner { min-width: 12px; min-height: 12px; }"
    ".talkies-hud button { box-shadow: none; text-shadow: none; outline: none; border: none;"
    "  -gtk-icon-shadow: none; transition: background 160ms ease-out, transform 240ms ease-out; }"
    ".talkies-hud button.circle { padding: 0; border-radius: 999px; background: rgba(255,255,255,0.08);"
    "  color: rgba(255,255,255,0.8); min-width: 38px; min-height: 38px; -gtk-icon-size: 14px; }"
    ".talkies-hud .mini button.circle { min-width: 30px; min-height: 30px; -gtk-icon-size: 12px;"
    "  color: rgba(255,255,255,0.75); }"
    ".talkies-hud button.circle:hover { background: rgba(255,255,255,0.14); }"
    ".talkies-hud button.close { min-width: 30px; min-height: 30px; -gtk-icon-size: 11px;"
    "  color: rgba(255,255,255,0.72); }"
    ".talkies-hud button.record { padding: 0; border-radius: 999px; min-width: 36px; min-height: 36px;"
    "  background: #38B36E; color: white; -gtk-icon-size: 13px; }"
    ".talkies-hud button.record:hover { background: #3fc27a; }"
    ".talkies-hud button.record.recording { background: #E04261; }"
    ".talkies-hud .mini button.record { min-width: 34px; min-height: 34px; -gtk-icon-size: 12px;"
    "  background: #6647D9; }"
    ".talkies-hud .mini button.record.recording { background: rgba(255,69,58,0.85); }"
    ".talkies-hud button.copy { padding: 0 11px; min-height: 32px; border-radius: 999px;"
    "  background: rgba(255,255,255,0.10); border: 1px solid rgba(255,255,255,0.12); }"
    ".talkies-hud button.copy label { font-size: 11px; font-weight: 600; }"
    ".talkies-hud button.copy image { -gtk-icon-size: 11px; color: white; }"
    ".talkies-hud .mini button.copy { padding: 0 9px; min-height: 26px; }"
    ".talkies-hud .mini button.copy label { font-size: 10px; }"
    ".talkies-hud button.copy.copied { background: rgba(48,209,88,0.25); border-color: rgba(48,209,88,0.55);"
    "  transform: scale(1.04); }"
    ".talkies-hud button.copy.copied label, .talkies-hud button.copy.copied image { color: #9EFFBA; }"
    ".talkies-hud button.clear { padding: 0 6px; min-height: 30px; background: transparent; }"
    ".talkies-hud button.clear label { font-size: 13px; color: rgba(255,255,255,0.7); }"
    ".talkies-hud button.clear:hover label { color: white; }"
    ".talkies-hud .history-title { font-size: 15px; font-weight: 600; }"
    ".talkies-hud .history-divider { background: rgba(255,255,255,0.1); min-height: 1px; }"
    ".talkies-hud .history-row { background: rgba(255,255,255,0.05); border-radius: 8px; padding: 12px; }"
    ".talkies-hud .history-time { font-family: monospace; font-size: 11px; color: rgba(255,255,255,0.5); }"
    ".talkies-hud .history-text { font-size: 13px; color: rgba(255,255,255,0.9); }"
    ".talkies-hud .history-empty { font-size: 14px; color: rgba(255,255,255,0.5); }"
    ".talkies-hud .history-row button.row-action { min-width: 26px; min-height: 26px; -gtk-icon-size: 11px;"
    "  color: rgba(255,255,255,0.7); }"
    ".talkies-hud entry.history-search, .talkies-hud .history-search { background: rgba(255,255,255,0.08);"
    "  color: white; border: none; box-shadow: none; border-radius: 8px; min-height: 30px; }"
    ".talkies-hud scrolledwindow, .talkies-hud viewport, .talkies-hud stack { background: transparent; }";

static GtkWidget *circle_button(const char *icon, const char *tooltip, GCallback callback, gpointer user_data) {
    GtkWidget *button = gtk_button_new_from_icon_name(icon);
    gtk_widget_add_css_class(button, "circle");
    gtk_widget_set_focusable(button, FALSE);
    gtk_widget_set_valign(button, GTK_ALIGN_CENTER);
    gtk_widget_set_tooltip_text(button, tooltip);
    g_signal_connect(button, "clicked", callback, user_data);
    return button;
}

static GtkWidget *drawing(int width, int height, GtkDrawingAreaDrawFunc func, gpointer user_data) {
    GtkWidget *area = gtk_drawing_area_new();
    if (width > 0) gtk_drawing_area_set_content_width(GTK_DRAWING_AREA(area), width);
    if (height > 0) gtk_drawing_area_set_content_height(GTK_DRAWING_AREA(area), height);
    gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(area), func, user_data, NULL);
    return area;
}

static void build_controls(TalkiesHud *hud, Controls *c, gboolean mini) {
    c->root = gtk_box_new(GTK_ORIENTATION_VERTICAL, mini ? 7 : 12);
    if (mini) gtk_widget_add_css_class(c->root, "mini");
    gtk_widget_set_margin_start(c->root, mini ? 14 : 20);
    gtk_widget_set_margin_end(c->root, mini ? 14 : 20);
    gtk_widget_set_margin_top(c->root, mini ? 10 : 17);
    gtk_widget_set_margin_bottom(c->root, mini ? 10 : 15);
    // The margins are inside the panel: shrink the request accordingly.
    gtk_widget_set_size_request(c->root, (int)(mini ? MINI_W - 28 : MAIN_W - 40),
                                (int)(mini ? MINI_H - 20 : MAIN_H - 32));

    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, mini ? 8 : 11);
    c->dot = drawing(mini ? 15 : 18, mini ? 15 : 18, draw_dot, hud);
    gtk_widget_set_valign(c->dot, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(top), c->dot);
    c->spinner = gtk_spinner_new();
    gtk_widget_add_css_class(c->spinner, "stage-tint");
    gtk_widget_set_valign(c->spinner, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(top), c->spinner);

    GtkWidget *texts = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    gtk_widget_set_valign(texts, GTK_ALIGN_CENTER);
    gtk_widget_set_hexpand(texts, TRUE);
    c->status = gtk_label_new("");
    gtk_widget_add_css_class(c->status, "status");
    gtk_label_set_xalign(GTK_LABEL(c->status), 0);
    gtk_label_set_ellipsize(GTK_LABEL(c->status), PANGO_ELLIPSIZE_END);
    // Natural width stays small so long text ellipsizes instead of widening the panel.
    gtk_label_set_max_width_chars(GTK_LABEL(c->status), 1);
    gtk_label_set_single_line_mode(GTK_LABEL(c->status), TRUE);
    gtk_box_append(GTK_BOX(texts), c->status);
    if (!mini) {
        c->hint = gtk_label_new("");
        gtk_widget_add_css_class(c->hint, "hint");
        gtk_label_set_xalign(GTK_LABEL(c->hint), 0);
        gtk_label_set_ellipsize(GTK_LABEL(c->hint), PANGO_ELLIPSIZE_END);
        // Natural width stays small so long text ellipsizes instead of widening the panel.
        gtk_label_set_max_width_chars(GTK_LABEL(c->hint), 1);
        gtk_label_set_single_line_mode(GTK_LABEL(c->hint), TRUE);
        gtk_box_append(GTK_BOX(texts), c->hint);
    }
    gtk_box_append(GTK_BOX(top), texts);

    c->history_button = circle_button("document-open-recent-symbolic", "Show recent transcripts",
                                      G_CALLBACK(on_history_clicked), hud);
    gtk_box_append(GTK_BOX(top), c->history_button);
    c->record_button = gtk_button_new_from_icon_name("audio-input-microphone-symbolic");
    gtk_widget_add_css_class(c->record_button, "record");
    gtk_widget_set_focusable(c->record_button, FALSE);
    gtk_widget_set_valign(c->record_button, GTK_ALIGN_CENTER);
    g_signal_connect(c->record_button, "clicked", G_CALLBACK(on_record_clicked), hud);
    gtk_box_append(GTK_BOX(top), c->record_button);
    gtk_box_append(GTK_BOX(c->root), top);

    c->waveform = drawing(0, mini ? 36 : 56, draw_waveform, hud);
    gtk_widget_set_hexpand(c->waveform, TRUE);
    gtk_box_append(GTK_BOX(c->root), c->waveform);

    GtkWidget *footer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 7);
    gtk_widget_set_vexpand(footer, TRUE);
    gtk_widget_set_valign(footer, GTK_ALIGN_CENTER);
    if (!mini) {
        c->footer_icon = gtk_image_new_from_icon_name("object-select-symbolic");
        gtk_widget_add_css_class(c->footer_icon, "footer-icon");
        gtk_widget_add_css_class(c->footer_icon, "stage-tint");
        gtk_box_append(GTK_BOX(footer), c->footer_icon);
    }
    c->footer_label = gtk_label_new("");
    gtk_widget_add_css_class(c->footer_label, mini ? "hint" : "footer");
    gtk_label_set_xalign(GTK_LABEL(c->footer_label), 0);
    gtk_label_set_ellipsize(GTK_LABEL(c->footer_label), PANGO_ELLIPSIZE_END);
    // Natural width stays small so long text ellipsizes instead of widening the panel.
    gtk_label_set_max_width_chars(GTK_LABEL(c->footer_label), 1);
    gtk_label_set_single_line_mode(GTK_LABEL(c->footer_label), TRUE);
    gtk_widget_set_hexpand(c->footer_label, TRUE);
    gtk_box_append(GTK_BOX(footer), c->footer_label);

    c->copy_button = gtk_button_new();
    gtk_widget_add_css_class(c->copy_button, "copy");
    gtk_widget_set_focusable(c->copy_button, FALSE);
    gtk_widget_set_valign(c->copy_button, GTK_ALIGN_CENTER);
    GtkWidget *copy_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    c->copy_icon = gtk_image_new_from_icon_name("edit-copy-symbolic");
    c->copy_label = gtk_label_new("Copy text");
    gtk_box_append(GTK_BOX(copy_box), c->copy_icon);
    gtk_box_append(GTK_BOX(copy_box), c->copy_label);
    gtk_button_set_child(GTK_BUTTON(c->copy_button), copy_box);
    g_signal_connect(c->copy_button, "clicked", mini ? G_CALLBACK(on_copy_mini) : G_CALLBACK(on_copy_main), hud);
    gtk_box_append(GTK_BOX(footer), c->copy_button);
    gtk_box_append(GTK_BOX(c->root), footer);
}

static GtkWidget *build_history(TalkiesHud *hud) {
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);

    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(header, 20);
    gtk_widget_set_margin_end(header, 20);
    gtk_widget_set_margin_top(header, 16);
    gtk_widget_set_margin_bottom(header, 12);
    GtkWidget *title = gtk_label_new("Transcript History");
    gtk_widget_add_css_class(title, "history-title");
    gtk_label_set_xalign(GTK_LABEL(title), 0);
    gtk_widget_set_hexpand(title, TRUE);
    gtk_box_append(GTK_BOX(header), title);
    hud->history_clear = gtk_button_new_with_label("Clear all");
    gtk_widget_add_css_class(hud->history_clear, "clear");
    gtk_widget_set_focusable(hud->history_clear, FALSE);
    gtk_widget_set_tooltip_text(hud->history_clear, "Delete every saved transcript");
    g_signal_connect(hud->history_clear, "clicked", G_CALLBACK(on_history_clear), hud);
    gtk_box_append(GTK_BOX(header), hud->history_clear);
    GtkWidget *close = circle_button("window-close-symbolic", "Close transcript history", G_CALLBACK(on_history_close), hud);
    gtk_widget_add_css_class(close, "close");
    gtk_box_append(GTK_BOX(header), close);
    gtk_box_append(GTK_BOX(page), header);

    hud->history_search = gtk_search_entry_new();
    g_object_set(hud->history_search, "placeholder-text", "Search transcripts", NULL);
    gtk_accessible_update_property(GTK_ACCESSIBLE(hud->history_search), GTK_ACCESSIBLE_PROPERTY_LABEL,
                                   "Search transcripts", -1);
    gtk_widget_add_css_class(hud->history_search, "history-search");
    gtk_widget_set_margin_start(hud->history_search, 20);
    gtk_widget_set_margin_end(hud->history_search, 20);
    gtk_widget_set_margin_bottom(hud->history_search, 12);
    g_signal_connect(hud->history_search, "search-changed", G_CALLBACK(on_history_search), hud);
    gtk_box_append(GTK_BOX(page), hud->history_search);

    GtkWidget *divider = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_add_css_class(divider, "history-divider");
    gtk_box_append(GTK_BOX(page), divider);

    GtkWidget *scroller = gtk_scrolled_window_new();
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroller), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_widget_set_vexpand(scroller, TRUE);
    hud->history_list = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_widget_set_margin_start(hud->history_list, 20);
    gtk_widget_set_margin_end(hud->history_list, 20);
    gtk_widget_set_margin_top(hud->history_list, 20);
    gtk_widget_set_margin_bottom(hud->history_list, 20);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), hud->history_list);
    gtk_box_append(GTK_BOX(page), scroller);
    return page;
}

static GtkWidget *history_row(TalkiesHud *hud, HistoryEntry *entry) {
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_widget_add_css_class(row, "history-row");
    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    GtkWidget *time = gtk_label_new(entry->time);
    gtk_widget_add_css_class(time, "history-time");
    gtk_label_set_xalign(GTK_LABEL(time), 0);
    gtk_widget_set_hexpand(time, TRUE);
    gtk_box_append(GTK_BOX(top), time);
    GtkWidget *copy = circle_button("edit-copy-symbolic", "Copy transcript", G_CALLBACK(on_history_copy), hud);
    gtk_widget_add_css_class(copy, "row-action");
    g_object_set_data(G_OBJECT(copy), "entry", entry);
    gtk_box_append(GTK_BOX(top), copy);
    GtkWidget *remove = circle_button("user-trash-symbolic", "Delete transcript", G_CALLBACK(on_history_delete), hud);
    gtk_widget_add_css_class(remove, "row-action");
    g_object_set_data(G_OBJECT(remove), "entry", entry);
    gtk_box_append(GTK_BOX(top), remove);
    GtkWidget *text = gtk_label_new(entry->text);
    gtk_widget_add_css_class(text, "history-text");
    gtk_label_set_xalign(GTK_LABEL(text), 0);
    gtk_label_set_wrap(GTK_LABEL(text), TRUE);
    gtk_label_set_wrap_mode(GTK_LABEL(text), PANGO_WRAP_WORD_CHAR);
    gtk_label_set_selectable(GTK_LABEL(text), TRUE);
    gtk_box_append(GTK_BOX(row), top);
    gtk_box_append(GTK_BOX(row), text);
    return row;
}

static void rebuild_history(TalkiesHud *hud) {
    GtkWidget *child;
    while ((child = gtk_widget_get_first_child(hud->history_list))) gtk_box_remove(GTK_BOX(hud->history_list), child);
    const char *search = history_search_text(hud);
    guint shown = 0;
    // Unsaved entries of this session first: they are the newest.
    for (guint i = 0; i < hud->session->len; i++) {
        HistoryEntry *entry = g_ptr_array_index(hud->session, i);
        if (!history_matches(entry->text, search)) continue;
        gtk_box_append(GTK_BOX(hud->history_list), history_row(hud, entry));
        shown++;
    }
    for (guint i = 0; i < hud->history->len; i++) {
        gtk_box_append(GTK_BOX(hud->history_list), history_row(hud, g_ptr_array_index(hud->history, i)));
        shown++;
    }
    if (shown == 0) {
        GtkWidget *empty = gtk_label_new(has_text(search) ? "No matching transcripts" : "No transcripts yet");
        gtk_widget_add_css_class(empty, "history-empty");
        gtk_widget_set_margin_top(empty, 40);
        gtk_box_append(GTK_BOX(hud->history_list), empty);
    }
    if (hud->history_more) {
        GtkWidget *more = gtk_button_new_with_label("Show older");
        gtk_widget_add_css_class(more, "clear");
        gtk_widget_set_focusable(more, FALSE);
        gtk_widget_set_halign(more, GTK_ALIGN_CENTER);
        g_signal_connect(more, "clicked", G_CALLBACK(on_history_more), hud);
        gtk_box_append(GTK_BOX(hud->history_list), more);
    }
}

TalkiesHud *talkies_hud_new(void) {
    if (!talkies_ui_init()) return NULL;

    TalkiesHud *hud = g_malloc0(sizeof *hud);
    hud->start_us = g_get_monotonic_time();
    hud->history = g_ptr_array_new_with_free_func(history_entry_free);
    hud->session = g_ptr_array_new_with_free_func(history_entry_free);
    hud->width = (Spring){PILL_W, 0, PILL_W};
    hud->height = (Spring){PILL_H, 0, PILL_H};

    hud->window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(hud->window), "Talkies Dictation");
    gtk_window_set_decorated(GTK_WINDOW(hud->window), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(hud->window), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(hud->window), WIN_W, WIN_H);
    gtk_widget_set_size_request(hud->window, WIN_W, WIN_H);
    gtk_widget_set_focusable(hud->window, FALSE);
    gtk_widget_add_css_class(hud->window, "talkies-hud");
    try_layer_shell(hud);
    g_signal_connect(hud->window, "close-request", G_CALLBACK(on_close_request), hud);
    g_signal_connect(hud->window, "realize", G_CALLBACK(on_realize), hud);
    g_signal_connect(hud->window, "map", G_CALLBACK(on_map), hud);

    // Above USER priority: a ~/.config/gtk-4.0/gtk.css that paints every
    // window would otherwise fill the transparent margins around the panel.
    // Every selector is scoped to .talkies-hud, so nothing else is affected.
    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_string(css, hud_css);
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(css),
                                               GTK_STYLE_PROVIDER_PRIORITY_USER + 1);
    g_object_unref(css);
    hud->tint_css = gtk_css_provider_new();
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(hud->tint_css),
                                               GTK_STYLE_PROVIDER_PRIORITY_USER + 2);

    GtkWidget *overlay = gtk_overlay_new();
    gtk_window_set_child(GTK_WINDOW(hud->window), overlay);
    hud->backdrop = drawing(WIN_W, WIN_H, draw_backdrop, hud);
    gtk_overlay_set_child(GTK_OVERLAY(overlay), hud->backdrop);

    // GtkWindowHandle lets the panel be dragged like the macOS one.
    GtkWidget *handle = gtk_window_handle_new();
    gtk_widget_set_halign(handle, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(handle, GTK_ALIGN_START);
    gtk_widget_set_margin_top(handle, TALKIES_HUD_PANEL_TOP);
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), handle);

    hud->stack = gtk_stack_new();
    gtk_stack_set_hhomogeneous(GTK_STACK(hud->stack), FALSE);
    gtk_stack_set_vhomogeneous(GTK_STACK(hud->stack), FALSE);
    gtk_stack_set_transition_type(GTK_STACK(hud->stack), GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_stack_set_transition_duration(GTK_STACK(hud->stack), 180);
    gtk_widget_set_halign(hud->stack, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(hud->stack, GTK_ALIGN_START);
    gtk_window_handle_set_child(GTK_WINDOW_HANDLE(handle), hud->stack);

    GtkEventController *motion = gtk_event_controller_motion_new();
    g_signal_connect(motion, "enter", G_CALLBACK(on_pointer_enter), hud);
    g_signal_connect(motion, "leave", G_CALLBACK(on_pointer_leave), hud);
    gtk_widget_add_controller(hud->stack, motion);

    // Collapsed: the waveform alone, 94x24 inside the 124x38 pill.
    GtkWidget *pill = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_widget_set_size_request(pill, (int)PILL_W, (int)PILL_H);
    gtk_widget_set_halign(pill, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(pill, GTK_ALIGN_START);
    hud->pill_waveform = drawing(94, 24, draw_waveform, hud);
    gtk_widget_set_margin_start(hud->pill_waveform, 15);
    gtk_widget_set_margin_end(hud->pill_waveform, 15);
    gtk_widget_set_margin_top(hud->pill_waveform, 7);
    gtk_widget_set_margin_bottom(hud->pill_waveform, 7);
    gtk_box_append(GTK_BOX(pill), hud->pill_waveform);
    GtkGesture *click = gtk_gesture_click_new();
    g_signal_connect(click, "pressed", G_CALLBACK(on_pill_pressed), hud);
    gtk_widget_add_controller(pill, GTK_EVENT_CONTROLLER(click));
    gtk_widget_set_cursor_from_name(pill, "pointer");
    gtk_stack_add_named(GTK_STACK(hud->stack), pill, "pill");

    build_controls(hud, &hud->main, FALSE);
    gtk_widget_set_valign(hud->main.root, GTK_ALIGN_START);
    gtk_stack_add_named(GTK_STACK(hud->stack), hud->main.root, "main");
    build_controls(hud, &hud->mini, TRUE);
    gtk_widget_set_valign(hud->mini.root, GTK_ALIGN_START);
    gtk_stack_add_named(GTK_STACK(hud->stack), hud->mini.root, "mini");

    hud->history_page = build_history(hud);
    gtk_widget_set_size_request(hud->history_page, (int)MAIN_W, (int)HISTORY_H);
    gtk_widget_set_valign(hud->history_page, GTK_ALIGN_START);
    gtk_stack_add_named(GTK_STACK(hud->stack), hud->history_page, "history");
    rebuild_history(hud);

    gtk_stack_set_visible_child_name(GTK_STACK(hud->stack), "pill");
    hud->stage = TALKIES_HUD_IDLE;
    refresh(hud);
    return hud;
}

void talkies_hud_destroy(TalkiesHud *hud) {
    if (!hud) return;
    cancel_leave(hud);
    if (hud->tick_id) gtk_widget_remove_tick_callback(hud->backdrop, hud->tick_id);
    if (hud->main.copy_reset_id) g_source_remove(hud->main.copy_reset_id);
    if (hud->mini.copy_reset_id) g_source_remove(hud->mini.copy_reset_id);
    if (hud->clear_reset_id) g_source_remove(hud->clear_reset_id);
    gtk_window_destroy(GTK_WINDOW(hud->window));
    g_object_unref(hud->tint_css);
    g_ptr_array_unref(hud->history);
    g_ptr_array_unref(hud->session);
    g_free(hud->detail);
    g_free(hud->transcript);
    g_free(hud->hotkey_name);
    g_free(hud->attention_status);
    g_free(hud->attention_hint);
    g_free(hud);
}

void talkies_hud_show(TalkiesHud *hud) {
    if (!hud || gtk_widget_get_visible(hud->window)) return;
    gtk_widget_set_visible(hud->window, TRUE);
    update_input_region(hud);
    ensure_ticking(hud);
}

void talkies_hud_hide(TalkiesHud *hud) {
    if (!hud) return;
    cancel_leave(hud);
    if (hud->tick_id) {
        gtk_widget_remove_tick_callback(hud->backdrop, hud->tick_id);
        hud->tick_id = 0;
    }
    gtk_widget_set_visible(hud->window, FALSE);
}

int talkies_hud_is_visible(TalkiesHud *hud) {
    return hud && gtk_widget_get_visible(hud->window);
}

void talkies_hud_set_expanded(TalkiesHud *hud, int expanded) {
    if (!hud) return;
    if (!expanded) {
        cancel_leave(hud);
        hud->show_history = FALSE;
    }
    hud->expanded = expanded != 0;
    apply_layout(hud);
}

int talkies_hud_is_expanded(TalkiesHud *hud) {
    return hud && hud->expanded;
}

void talkies_hud_set_mini(TalkiesHud *hud, int mini) {
    if (!hud || hud->mini_mode == (mini != 0)) return;
    hud->mini_mode = mini != 0;
    apply_layout(hud);
}

void talkies_hud_set_stage(TalkiesHud *hud, TalkiesHudStage stage, const char *detail) {
    if (!hud) return;
    TalkiesHudStage previous = hud->stage;
    hud->stage = stage;
    g_free(hud->detail);
    hud->detail = detail ? g_strdup(detail) : NULL;
    if (stage == TALKIES_HUD_RECORDING && previous != TALKIES_HUD_RECORDING) {
        memset(hud->samples, 0, sizeof hud->samples);
        hud->elapsed = 0;
        // A new recording clears the "Copied" badges.
        hud->main.copied = FALSE;
        hud->mini.copied = FALSE;
    }
    if (stage != TALKIES_HUD_RECORDING) hud->elapsed = 0;
    // Results that need reading stay until the pointer leaves.
    if (!stage_is_dismissable(stage)) cancel_leave(hud);
    refresh(hud);
    ensure_ticking(hud);
}

void talkies_hud_set_level(TalkiesHud *hud, float level) {
    if (!hud) return;
    memmove(hud->samples, hud->samples + 1, sizeof(float) * (SAMPLE_COUNT - 1));
    hud->samples[SAMPLE_COUNT - 1] = level < 0 ? 0 : (level > 1 ? 1 : level);
}

void talkies_hud_set_elapsed(TalkiesHud *hud, double seconds) {
    if (!hud) return;
    int changed = (int)seconds != (int)hud->elapsed;
    hud->elapsed = seconds;
    if (changed) refresh(hud);
}

void talkies_hud_set_transcript(TalkiesHud *hud, const char *text) {
    if (!hud) return;
    g_free(hud->transcript);
    hud->transcript = text ? g_strdup(text) : NULL;
    refresh(hud);
}

void talkies_hud_add_history(TalkiesHud *hud, long long id, long long created_at_ms, const char *text) {
    if (!hud || !has_text(text)) return;
    if (id == 0) {
        g_ptr_array_insert(hud->session, 0, history_entry_new(0, created_at_ms, text));
        if (hud->session->len > HISTORY_LIMIT) g_ptr_array_set_size(hud->session, HISTORY_LIMIT);
    } else if (history_matches(text, history_search_text(hud))) {
        g_ptr_array_insert(hud->history, 0, history_entry_new(id, created_at_ms, text));
    }
    rebuild_history(hud);
}

void talkies_hud_set_history_callbacks(TalkiesHud *hud, TalkiesHudHistoryQueryFn query, TalkiesHudHistoryDeleteFn remove,
                                       TalkiesHudCallback clear, void *user_data) {
    if (!hud) return;
    hud->history_query = query;
    hud->history_delete = remove;
    hud->history_clear_all = clear;
    hud->history_user_data = user_data;
    history_reload(hud);
}

void talkies_hud_history_append(TalkiesHud *hud, long long id, long long created_at_ms, const char *text) {
    if (!hud || !text) return;
    g_ptr_array_add(hud->history, history_entry_new(id, created_at_ms, text));
}

void talkies_hud_history_finish(TalkiesHud *hud, int has_more) {
    if (!hud) return;
    hud->history_more = has_more != 0;
}

void talkies_hud_set_hotkey_name(TalkiesHud *hud, const char *name) {
    if (!hud) return;
    g_free(hud->hotkey_name);
    hud->hotkey_name = name ? g_strdup(name) : NULL;
    refresh(hud);
}

void talkies_hud_set_attention(TalkiesHud *hud, const char *status, const char *hint) {
    if (!hud) return;
    g_free(hud->attention_status);
    g_free(hud->attention_hint);
    hud->attention_status = has_text(status) ? g_strdup(status) : NULL;
    hud->attention_hint = hud->attention_status && hint ? g_strdup(hint) : NULL;
    refresh(hud);
}

void talkies_hud_set_record_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data) {
    if (!hud) return;
    hud->record_callback = callback;
    hud->record_user_data = user_data;
}

void talkies_hud_set_dismiss_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data) {
    if (!hud) return;
    hud->dismiss_callback = callback;
    hud->dismiss_user_data = user_data;
}
