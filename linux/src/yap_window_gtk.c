#include "yap_window_gtk.h"
#include <gtk/gtk.h>
#include <string.h>

// Actual struct definition (not exposed in header)
struct YapWindowGtk {
    GtkWidget *window;
    GtkTextBuffer *context_buffer;       // Initial context input
    GtkTextBuffer *sandbox_buffer;       // Transcription sandbox (accumulates)
    GtkTextBuffer *history_buffer;       // Historical refinement view
    GtkWidget *context_view;             // Editable context view
    GtkWidget *sandbox_view;             // Editable sandbox view
    GtkWidget *history_view;             // Read-only history view
    GtkWidget *sandbox_chars_label;
    GtkWidget *revision_label;
    GtkWidget *accept_btn;
    GtkWidget *refine_btn;
    GtkWidget *cancel_btn;
    GtkWidget *clear_context_btn;
    GtkWidget *clear_sandbox_btn;
    void *user_data; // Points to Zig YapWindow struct
};

static int gtk_initialized = 0;

void yap_window_gtk_init(void) {
    if (!gtk_initialized) {
        gtk_init();
        gtk_initialized = 1;
    }
}

void yap_window_gtk_process_events(void) {
    // Process all pending GTK events without blocking
    while (g_main_context_pending(NULL)) {
        g_main_context_iteration(NULL, FALSE);
    }
}

YapWindowGtk* yap_window_gtk_new(void) {
    // Ensure GTK is initialized
    yap_window_gtk_init();

    YapWindowGtk *win = g_malloc0(sizeof(YapWindowGtk));

    // Create window
    win->window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(win->window), "YAP Mode - Conversational Transcription");
    gtk_window_set_default_size(GTK_WINDOW(win->window), 1000, 700);

    // Main vertical box
    GtkWidget *vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_start(vbox, 10);
    gtk_widget_set_margin_end(vbox, 10);
    gtk_widget_set_margin_top(vbox, 10);
    gtk_widget_set_margin_bottom(vbox, 10);
    gtk_window_set_child(GTK_WINDOW(win->window), vbox);

    // Header with stats
    GtkWidget *header_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_box_append(GTK_BOX(vbox), header_box);

    win->revision_label = gtk_label_new("Refinement: 0");
    win->sandbox_chars_label = gtk_label_new("Sandbox: 0 chars");

    gtk_box_append(GTK_BOX(header_box), win->revision_label);
    gtk_box_append(GTK_BOX(header_box), win->sandbox_chars_label);

    // === PART 1: Initial Context (top section) ===
    GtkWidget *context_header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    GtkWidget *context_label = gtk_label_new("🎯 Initial Context (optional)");
    gtk_widget_set_hexpand(context_label, TRUE);
    gtk_widget_set_halign(context_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(context_header), context_label);

    win->clear_context_btn = gtk_button_new_with_label("Clear");
    gtk_box_append(GTK_BOX(context_header), win->clear_context_btn);
    gtk_box_append(GTK_BOX(vbox), context_header);

    GtkWidget *context_scroll = gtk_scrolled_window_new();
    gtk_widget_set_size_request(context_scroll, -1, 100);
    win->context_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(win->context_view), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->context_view), GTK_WRAP_WORD);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->context_view), FALSE);
    win->context_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->context_view));
    gtk_text_buffer_set_text(win->context_buffer, "Enter background context, instructions, or topic information here...", -1);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(context_scroll), win->context_view);
    gtk_box_append(GTK_BOX(vbox), context_scroll);

    // === PART 2: Transcription Sandbox (middle section - largest) ===
    GtkWidget *sandbox_header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    GtkWidget *sandbox_label = gtk_label_new("🎤 Transcription Sandbox (your yapping goes here)");
    gtk_widget_set_hexpand(sandbox_label, TRUE);
    gtk_widget_set_halign(sandbox_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(sandbox_header), sandbox_label);

    win->clear_sandbox_btn = gtk_button_new_with_label("Clear");
    gtk_box_append(GTK_BOX(sandbox_header), win->clear_sandbox_btn);
    gtk_box_append(GTK_BOX(vbox), sandbox_header);

    GtkWidget *sandbox_scroll = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(sandbox_scroll, TRUE);
    gtk_widget_set_size_request(sandbox_scroll, -1, 250);
    win->sandbox_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(win->sandbox_view), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->sandbox_view), GTK_WRAP_WORD);
    win->sandbox_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->sandbox_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(sandbox_scroll), win->sandbox_view);
    gtk_box_append(GTK_BOX(vbox), sandbox_scroll);

    // === PART 3: Refinement History (bottom section - collapsible) ===
    GtkWidget *history_expander = gtk_expander_new("📜 Refinement History (context + sandbox → refined output)");
    gtk_expander_set_expanded(GTK_EXPANDER(history_expander), TRUE);
    gtk_box_append(GTK_BOX(vbox), history_expander);

    GtkWidget *history_scroll = gtk_scrolled_window_new();
    gtk_widget_set_size_request(history_scroll, -1, 150);
    win->history_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(win->history_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->history_view), GTK_WRAP_WORD);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->history_view), TRUE);
    win->history_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->history_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(history_scroll), win->history_view);
    gtk_expander_set_child(GTK_EXPANDER(history_expander), history_scroll);

    // Button row
    GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_halign(btn_box, GTK_ALIGN_END);
    gtk_box_append(GTK_BOX(vbox), btn_box);

    win->cancel_btn = gtk_button_new_with_label("❌ Cancel");
    gtk_box_append(GTK_BOX(btn_box), win->cancel_btn);

    win->refine_btn = gtk_button_new_with_label("✨ Refine with LLM");
    gtk_box_append(GTK_BOX(btn_box), win->refine_btn);

    win->accept_btn = gtk_button_new_with_label("✅ Accept & Paste");
    gtk_box_append(GTK_BOX(btn_box), win->accept_btn);

    return win;
}

void yap_window_gtk_destroy(YapWindowGtk *win) {
    if (win) {
        gtk_window_destroy(GTK_WINDOW(win->window));
        g_free(win);
    }
}

void yap_window_gtk_show(YapWindowGtk *win) {
    gtk_widget_set_visible(win->window, TRUE);
}

void yap_window_gtk_hide(YapWindowGtk *win) {
    gtk_widget_set_visible(win->window, FALSE);
}

void yap_window_gtk_connect_signals(
    YapWindowGtk *win,
    void (*on_accept)(void*),
    void (*on_refine)(void*),
    void (*on_cancel)(void*),
    void *user_data
) {
    win->user_data = user_data;

    g_signal_connect_swapped(win->accept_btn, "clicked", G_CALLBACK(on_accept), user_data);
    g_signal_connect_swapped(win->refine_btn, "clicked", G_CALLBACK(on_refine), user_data);
    g_signal_connect_swapped(win->cancel_btn, "clicked", G_CALLBACK(on_cancel), user_data);
}

// Context management
void yap_window_gtk_set_context_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->context_buffer, text, len);
}

const char* yap_window_gtk_get_context_text(YapWindowGtk *win) {
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(win->context_buffer, &start, &end);
    return gtk_text_buffer_get_text(win->context_buffer, &start, &end, FALSE);
}

void yap_window_gtk_clear_context(YapWindowGtk *win) {
    gtk_text_buffer_set_text(win->context_buffer, "", -1);
}

// Sandbox management
void yap_window_gtk_set_sandbox_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->sandbox_buffer, text, len);
}

void yap_window_gtk_append_sandbox_text(YapWindowGtk *win, const char *text, int len) {
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(win->sandbox_buffer, &end);
    gtk_text_buffer_insert(win->sandbox_buffer, &end, text, len);
}

const char* yap_window_gtk_get_sandbox_text(YapWindowGtk *win) {
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(win->sandbox_buffer, &start, &end);
    return gtk_text_buffer_get_text(win->sandbox_buffer, &start, &end, FALSE);
}

void yap_window_gtk_clear_sandbox(YapWindowGtk *win) {
    gtk_text_buffer_set_text(win->sandbox_buffer, "", -1);
}

// History management
void yap_window_gtk_set_history_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->history_buffer, text, len);
}

void yap_window_gtk_append_history_text(YapWindowGtk *win, const char *text, int len) {
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(win->history_buffer, &end);
    gtk_text_buffer_insert(win->history_buffer, &end, text, len);
}

// Stats
void yap_window_gtk_set_revision(YapWindowGtk *win, int revision) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Refinement: %d", revision);
    gtk_label_set_text(GTK_LABEL(win->revision_label), buf);
}

void yap_window_gtk_set_sandbox_chars(YapWindowGtk *win, int chars) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Sandbox: %d chars", chars);
    gtk_label_set_text(GTK_LABEL(win->sandbox_chars_label), buf);
}
