#include "daemon_status_gtk.h"
#include "loop_glib.h"
#include "gtk_compat.h"
#include <string.h>
#include <time.h>

// Actual struct definition
struct DaemonStatusWindow {
    GtkWidget *window;

    // Status indicators
    GtkWidget *state_label;
    GtkWidget *model_label;
    GtkWidget *platform_label;
    GtkWidget *clients_label;
    GtkWidget *yap_indicator;
    GtkWidget *ollama_indicator;

    // Activity section
    GtkWidget *activity_label;
    GtkWidget *last_transcription_label;

    // Log viewer
    GtkWidget *log_view;
    GtkTextBuffer *log_buffer;
    GtkTextTag *info_tag;
    GtkTextTag *warn_tag;
    GtkTextTag *error_tag;
    GtkTextTag *debug_tag;
    GtkWidget *auto_scroll_check;

    // Statistics
    GtkWidget *sessions_label;
    GtkWidget *errors_label;
    GtkWidget *avg_duration_label;

    // Callbacks
    void (*settings_callback)(void*);
    void *settings_user_data;
};

int daemon_status_gtk_init(void) {
    return talkies_ui_init();
}

void daemon_status_gtk_process_events(void) {
    // Process all pending GTK events without blocking
    while (g_main_context_pending(NULL)) {
        g_main_context_iteration(NULL, FALSE);
    }
}

static void on_clear_logs_clicked(GtkButton *button, gpointer user_data) {
    DaemonStatusWindow *win = (DaemonStatusWindow*)user_data;
    daemon_status_window_clear_logs(win);
}

static void on_settings_clicked(GtkButton *button, gpointer user_data) {
    DaemonStatusWindow *win = (DaemonStatusWindow*)user_data;
    if (win && win->settings_callback) {
        win->settings_callback(win->settings_user_data);
    }
}

static gboolean on_close_request(GtkWindow *window, gpointer user_data) {
    // Closing the status window should hide it without stopping the daemon.
    (void)user_data;
    gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
    return TRUE;
}

DaemonStatusWindow* daemon_status_window_new(void) {
    if (!daemon_status_gtk_init()) return NULL;

    DaemonStatusWindow *win = g_malloc0(sizeof(DaemonStatusWindow));

    // Create main window
    win->window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(win->window), "Talkies Daemon - Status Monitor");
    gtk_window_set_default_size(GTK_WINDOW(win->window), 800, 600);
    gtk_widget_add_css_class(win->window, "talkies-monitor");
    g_signal_connect(win->window, "close-request", G_CALLBACK(on_close_request), win);

    // Apply Tokyo Night dark theme
    GtkCssProvider *css_provider = gtk_css_provider_new();
    // Scoped to this window: an unscoped theme would restyle every Talkies
    // window (Settings, the dictation panel) once this one exists.
    const char *tokyo_night_css =
        "window.talkies-monitor {"
        "  background-color: #1a1b26;"
        "  color: #c0caf5;"
        "}"
        ".talkies-monitor label {"
        "  color: #c0caf5;"
        "}"
        ".talkies-monitor textview {"
        "  background-color: #24283b;"
        "  color: #c0caf5;"
        "  caret-color: #c0caf5;"
        "}"
        ".talkies-monitor textview text {"
        "  background-color: #24283b;"
        "  color: #c0caf5;"
        "}"
        ".talkies-monitor button {"
        "  background-color: #414868;"
        "  color: #c0caf5;"
        "  border: 1px solid #565f89;"
        "  border-radius: 4px;"
        "  padding: 6px 12px;"
        "}"
        ".talkies-monitor button:hover {"
        "  background-color: #565f89;"
        "}"
        ".talkies-monitor scrolledwindow {"
        "  background-color: #24283b;"
        "}"
        ".talkies-monitor checkbutton {"
        "  color: #c0caf5;"
        "}";

    gtk_css_provider_load_from_string(css_provider, tokyo_night_css);
    gtk_style_context_add_provider_for_display(
        gdk_display_get_default(),
        GTK_STYLE_PROVIDER(css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION
    );
    g_object_unref(css_provider);

    // Main vertical box
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_start(vbox, 10);
    gtk_widget_set_margin_end(vbox, 10);
    gtk_widget_set_margin_top(vbox, 10);
    gtk_widget_set_margin_bottom(vbox, 10);
    gtk_window_set_child(GTK_WINDOW(win->window), vbox);

    // === Status Section ===
    GtkWidget *status_frame = gtk_frame_new("Status");
    gtk_box_append(GTK_BOX(vbox), status_frame);

    GtkWidget *status_grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(status_grid), 5);
    gtk_grid_set_column_spacing(GTK_GRID(status_grid), 15);
    gtk_widget_set_margin_start(status_grid, 10);
    gtk_widget_set_margin_end(status_grid, 10);
    gtk_widget_set_margin_top(status_grid, 10);
    gtk_widget_set_margin_bottom(status_grid, 10);
    gtk_frame_set_child(GTK_FRAME(status_frame), status_grid);

    // Row 1: State, Model, Platform
    win->state_label = gtk_label_new("🟢 IDLE");
    gtk_widget_set_halign(win->state_label, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(status_grid), win->state_label, 0, 0, 1, 1);

    GtkWidget *model_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(model_box), gtk_label_new("Model:"));
    win->model_label = gtk_label_new("small");
    gtk_box_append(GTK_BOX(model_box), win->model_label);
    gtk_grid_attach(GTK_GRID(status_grid), model_box, 1, 0, 1, 1);

    GtkWidget *platform_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(platform_box), gtk_label_new("Platform:"));
    win->platform_label = gtk_label_new("wayland");
    gtk_box_append(GTK_BOX(platform_box), win->platform_label);
    gtk_grid_attach(GTK_GRID(status_grid), platform_box, 2, 0, 1, 1);

    // Row 2: Clients, YAP, Ollama
    GtkWidget *clients_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(clients_box), gtk_label_new("Clients:"));
    win->clients_label = gtk_label_new("0");
    gtk_box_append(GTK_BOX(clients_box), win->clients_label);
    gtk_grid_attach(GTK_GRID(status_grid), clients_box, 0, 1, 1, 1);

    GtkWidget *yap_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(yap_box), gtk_label_new("YAP Mode:"));
    win->yap_indicator = gtk_label_new("✗");
    gtk_box_append(GTK_BOX(yap_box), win->yap_indicator);
    gtk_grid_attach(GTK_GRID(status_grid), yap_box, 1, 1, 1, 1);

    GtkWidget *ollama_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(ollama_box), gtk_label_new("Ollama:"));
    win->ollama_indicator = gtk_label_new("✗");
    gtk_box_append(GTK_BOX(ollama_box), win->ollama_indicator);
    gtk_grid_attach(GTK_GRID(status_grid), ollama_box, 2, 1, 1, 1);

    // === Activity Section ===
    GtkWidget *activity_frame = gtk_frame_new("Current Activity");
    gtk_box_append(GTK_BOX(vbox), activity_frame);

    GtkWidget *activity_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    gtk_widget_set_margin_start(activity_vbox, 10);
    gtk_widget_set_margin_end(activity_vbox, 10);
    gtk_widget_set_margin_top(activity_vbox, 10);
    gtk_widget_set_margin_bottom(activity_vbox, 10);
    gtk_frame_set_child(GTK_FRAME(activity_frame), activity_vbox);

    win->activity_label = gtk_label_new("No active recording");
    gtk_widget_set_halign(win->activity_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(activity_vbox), win->activity_label);

    win->last_transcription_label = gtk_label_new("Last transcription: Never");
    gtk_widget_set_halign(win->last_transcription_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(activity_vbox), win->last_transcription_label);

    // === Logs Section ===
    GtkWidget *logs_header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    GtkWidget *logs_label = gtk_label_new("Logs");
    gtk_widget_set_hexpand(logs_label, TRUE);
    gtk_widget_set_halign(logs_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(logs_header), logs_label);

    GtkWidget *clear_btn = gtk_button_new_with_label("Clear");
    g_signal_connect(clear_btn, "clicked", G_CALLBACK(on_clear_logs_clicked), win);
    gtk_box_append(GTK_BOX(logs_header), clear_btn);

    gtk_box_append(GTK_BOX(vbox), logs_header);

    // Log viewer with scroll
    GtkWidget *log_scroll = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(log_scroll, TRUE);
    gtk_widget_set_size_request(log_scroll, -1, 300);
    gtk_box_append(GTK_BOX(vbox), log_scroll);

    win->log_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(win->log_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->log_view), GTK_WRAP_WORD);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->log_view), TRUE);
    win->log_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->log_view));

    // Create text tags for different log levels
    win->info_tag = gtk_text_buffer_create_tag(win->log_buffer, "info", "foreground", "#2196F3", NULL);
    win->warn_tag = gtk_text_buffer_create_tag(win->log_buffer, "warn", "foreground", "#FF9800", NULL);
    win->error_tag = gtk_text_buffer_create_tag(win->log_buffer, "error", "foreground", "#F44336", "weight", PANGO_WEIGHT_BOLD, NULL);
    win->debug_tag = gtk_text_buffer_create_tag(win->log_buffer, "debug", "foreground", "#9E9E9E", NULL);

    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(log_scroll), win->log_view);

    // Auto-scroll checkbox
    GtkWidget *log_controls = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    win->auto_scroll_check = gtk_check_button_new_with_label("Auto-scroll");
    gtk_check_button_set_active(GTK_CHECK_BUTTON(win->auto_scroll_check), TRUE);
    gtk_box_append(GTK_BOX(log_controls), win->auto_scroll_check);
    gtk_box_append(GTK_BOX(vbox), log_controls);

    // === Statistics Section ===
    GtkWidget *stats_frame = gtk_frame_new("Statistics");
    gtk_box_append(GTK_BOX(vbox), stats_frame);

    GtkWidget *stats_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 20);
    gtk_widget_set_margin_start(stats_box, 10);
    gtk_widget_set_margin_end(stats_box, 10);
    gtk_widget_set_margin_top(stats_box, 10);
    gtk_widget_set_margin_bottom(stats_box, 10);
    gtk_frame_set_child(GTK_FRAME(stats_frame), stats_box);

    GtkWidget *sessions_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(sessions_box), gtk_label_new("Sessions:"));
    win->sessions_label = gtk_label_new("0");
    gtk_box_append(GTK_BOX(sessions_box), win->sessions_label);
    gtk_box_append(GTK_BOX(stats_box), sessions_box);

    GtkWidget *errors_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(errors_box), gtk_label_new("Errors:"));
    win->errors_label = gtk_label_new("0");
    gtk_box_append(GTK_BOX(errors_box), win->errors_label);
    gtk_box_append(GTK_BOX(stats_box), errors_box);

    GtkWidget *avg_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(avg_box), gtk_label_new("Avg Duration:"));
    win->avg_duration_label = gtk_label_new("0.0s");
    gtk_box_append(GTK_BOX(avg_box), win->avg_duration_label);
    gtk_box_append(GTK_BOX(stats_box), avg_box);

    // === Bottom buttons ===
    GtkWidget *button_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_halign(button_box, GTK_ALIGN_END);
    gtk_box_append(GTK_BOX(vbox), button_box);

    GtkWidget *settings_btn = gtk_button_new_with_label("Settings");
    g_signal_connect(settings_btn, "clicked", G_CALLBACK(on_settings_clicked), win);
    gtk_box_append(GTK_BOX(button_box), settings_btn);

    return win;
}

void daemon_status_window_destroy(DaemonStatusWindow *win) {
    if (win) {
        gtk_window_destroy(GTK_WINDOW(win->window));
        g_free(win);
    }
}

void daemon_status_window_show(DaemonStatusWindow *win) {
    if (win && GTK_IS_WIDGET(win->window)) gtk_widget_set_visible(win->window, TRUE);
}

void daemon_status_window_hide(DaemonStatusWindow *win) {
    if (win && GTK_IS_WIDGET(win->window)) gtk_widget_set_visible(win->window, FALSE);
}

// Status updates
void daemon_status_window_set_state(DaemonStatusWindow *win, const char *state) {
    if (!win || !GTK_IS_LABEL(win->state_label) || !state) return;
    char buf[128];
    const char *emoji = "🟢";

    if (strcmp(state, "recording") == 0) emoji = "🔴";
    else if (strcmp(state, "processing") == 0) emoji = "⚙️";
    else if (strcmp(state, "yap_refining") == 0) emoji = "💬";

    snprintf(buf, sizeof(buf), "%s %s", emoji, state);
    gtk_label_set_text(GTK_LABEL(win->state_label), buf);
}

void daemon_status_window_set_model(DaemonStatusWindow *win, const char *model) {
    if (!win || !GTK_IS_LABEL(win->model_label) || !model) return;
    gtk_label_set_text(GTK_LABEL(win->model_label), model);
}

void daemon_status_window_set_platform(DaemonStatusWindow *win, const char *platform) {
    if (!win || !GTK_IS_LABEL(win->platform_label) || !platform) return;
    gtk_label_set_text(GTK_LABEL(win->platform_label), platform);
}

void daemon_status_window_set_clients(DaemonStatusWindow *win, int count) {
    if (!win || !GTK_IS_LABEL(win->clients_label)) return;
    char buf[32];
    snprintf(buf, sizeof(buf), "%d", count);
    gtk_label_set_text(GTK_LABEL(win->clients_label), buf);
}

void daemon_status_window_set_yap_enabled(DaemonStatusWindow *win, int enabled) {
    if (!win || !GTK_IS_LABEL(win->yap_indicator)) return;
    gtk_label_set_text(GTK_LABEL(win->yap_indicator), enabled ? "✓" : "✗");
}

void daemon_status_window_set_ollama_connected(DaemonStatusWindow *win, int connected) {
    if (!win || !GTK_IS_LABEL(win->ollama_indicator)) return;
    gtk_label_set_text(GTK_LABEL(win->ollama_indicator), connected ? "✓" : "✗");
}

void daemon_status_window_set_activity(DaemonStatusWindow *win, const char *activity) {
    if (!win || !GTK_IS_LABEL(win->activity_label) || !activity) return;
    gtk_label_set_text(GTK_LABEL(win->activity_label), activity);
}

void daemon_status_window_set_last_transcription(DaemonStatusWindow *win, const char *time) {
    if (!win || !GTK_IS_LABEL(win->last_transcription_label) || !time) return;
    char buf[128];
    snprintf(buf, sizeof(buf), "Last transcription: %s", time);
    gtk_label_set_text(GTK_LABEL(win->last_transcription_label), buf);
}

void daemon_status_window_add_log(DaemonStatusWindow *win, LogLevel level, const char *message) {
    if (!win || !GTK_IS_TEXT_BUFFER(win->log_buffer) ||
        !GTK_IS_CHECK_BUTTON(win->auto_scroll_check) || !GTK_IS_TEXT_VIEW(win->log_view) ||
        !message) return;
    // Get current time
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&now);
    char time_str[16];
    strftime(time_str, sizeof(time_str), "%H:%M:%S", tm_info);

    // Determine tag and level string
    GtkTextTag *tag;
    const char *level_str;

    switch (level) {
        case LOG_LEVEL_INFO:
            tag = win->info_tag;
            level_str = "INFO";
            break;
        case LOG_LEVEL_WARN:
            tag = win->warn_tag;
            level_str = "WARN";
            break;
        case LOG_LEVEL_ERROR:
            tag = win->error_tag;
            level_str = "ERROR";
            break;
        case LOG_LEVEL_DEBUG:
            tag = win->debug_tag;
            level_str = "DEBUG";
            break;
        default:
            tag = win->info_tag;
            level_str = "INFO";
    }

    // Format log entry
    char log_entry[1024];
    snprintf(log_entry, sizeof(log_entry), "%s [%s] %s\n", time_str, level_str, message);

    // Append to buffer
    GtkTextIter iter;
    gtk_text_buffer_get_end_iter(win->log_buffer, &iter);
    gtk_text_buffer_insert_with_tags(win->log_buffer, &iter, log_entry, -1, tag, NULL);

    // Auto-scroll if enabled
    if (gtk_check_button_get_active(GTK_CHECK_BUTTON(win->auto_scroll_check))) {
        GtkTextIter end;
        gtk_text_buffer_get_end_iter(win->log_buffer, &end);
        GtkTextMark *mark = gtk_text_buffer_create_mark(win->log_buffer, NULL, &end, FALSE);
        gtk_text_view_scroll_to_mark(GTK_TEXT_VIEW(win->log_view), mark, 0.0, TRUE, 0.0, 1.0);
        gtk_text_buffer_delete_mark(win->log_buffer, mark);
    }
}

void daemon_status_window_clear_logs(DaemonStatusWindow *win) {
    if (!win || !GTK_IS_TEXT_BUFFER(win->log_buffer)) return;
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(win->log_buffer, &start, &end);
    gtk_text_buffer_delete(win->log_buffer, &start, &end);
}

void daemon_status_window_set_stats(DaemonStatusWindow *win, int sessions, int errors, float avg_duration) {
    if (!win || !GTK_IS_LABEL(win->sessions_label) || !GTK_IS_LABEL(win->errors_label) ||
        !GTK_IS_LABEL(win->avg_duration_label)) return;
    char buf[32];

    snprintf(buf, sizeof(buf), "%d", sessions);
    gtk_label_set_text(GTK_LABEL(win->sessions_label), buf);

    snprintf(buf, sizeof(buf), "%d", errors);
    gtk_label_set_text(GTK_LABEL(win->errors_label), buf);

    snprintf(buf, sizeof(buf), "%.1fs", avg_duration);
    gtk_label_set_text(GTK_LABEL(win->avg_duration_label), buf);
}

void daemon_status_window_set_settings_callback(DaemonStatusWindow *win, void (*callback)(void*), void *user_data) {
    if (!win) return;
    win->settings_callback = callback;
    win->settings_user_data = user_data;
}
