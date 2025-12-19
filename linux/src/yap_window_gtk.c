#include "yap_window_gtk.h"
#include <gtk/gtk.h>
#include <string.h>

// Actual struct definition (not exposed in header)
struct YapWindowGtk {
    GtkWidget *window;
    GtkTextBuffer *original_buffer;
    GtkTextBuffer *refined_buffer;
    GtkTextBuffer *history_buffer;
    GtkWidget *refine_input;
    GtkWidget *original_chars_label;
    GtkWidget *refined_chars_label;
    GtkWidget *compression_label;
    GtkWidget *revision_label;
    GtkWidget *accept_btn;
    GtkWidget *refine_btn;
    GtkWidget *cancel_btn;
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
    gtk_window_set_title(GTK_WINDOW(win->window), "YAP Mode - Interactive Refinement");
    gtk_window_set_default_size(GTK_WINDOW(win->window), 800, 600);

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

    win->revision_label = gtk_label_new("Revision: 1");
    win->original_chars_label = gtk_label_new("Original: 0 chars");
    win->refined_chars_label = gtk_label_new("Refined: 0 chars");
    win->compression_label = gtk_label_new("Compression: 100%");

    gtk_box_append(GTK_BOX(header_box), win->revision_label);
    gtk_box_append(GTK_BOX(header_box), win->original_chars_label);
    gtk_box_append(GTK_BOX(header_box), win->refined_chars_label);
    gtk_box_append(GTK_BOX(header_box), win->compression_label);

    // Paned view for original and refined
    GtkWidget *paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_widget_set_vexpand(paned, TRUE);
    gtk_box_append(GTK_BOX(vbox), paned);

    // Left side: Original transcription
    GtkWidget *left_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    GtkWidget *original_label = gtk_label_new("📝 Original Transcription");
    gtk_box_append(GTK_BOX(left_vbox), original_label);

    GtkWidget *original_scroll = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(original_scroll, TRUE);
    GtkWidget *original_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(original_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(original_view), GTK_WRAP_WORD);
    win->original_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(original_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(original_scroll), original_view);
    gtk_box_append(GTK_BOX(left_vbox), original_scroll);

    gtk_paned_set_start_child(GTK_PANED(paned), left_vbox);

    // Right side: Refined version
    GtkWidget *right_vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 5);
    GtkWidget *refined_label = gtk_label_new("✨ Refined Version");
    gtk_box_append(GTK_BOX(right_vbox), refined_label);

    GtkWidget *refined_scroll = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(refined_scroll, TRUE);
    GtkWidget *refined_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(refined_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(refined_view), GTK_WRAP_WORD);
    win->refined_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(refined_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(refined_scroll), refined_view);
    gtk_box_append(GTK_BOX(right_vbox), refined_scroll);

    gtk_paned_set_end_child(GTK_PANED(paned), right_vbox);

    // History section (collapsible)
    GtkWidget *history_expander = gtk_expander_new("📜 Revision History");
    gtk_box_append(GTK_BOX(vbox), history_expander);

    GtkWidget *history_scroll = gtk_scrolled_window_new();
    gtk_widget_set_size_request(history_scroll, -1, 150);
    GtkWidget *history_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(history_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(history_view), GTK_WRAP_WORD);
    win->history_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(history_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(history_scroll), history_view);
    gtk_expander_set_child(GTK_EXPANDER(history_expander), history_scroll);

    // Refine input section
    GtkWidget *refine_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 5);
    gtk_box_append(GTK_BOX(vbox), refine_box);

    GtkWidget *refine_label = gtk_label_new("Additional instructions:");
    gtk_box_append(GTK_BOX(refine_box), refine_label);

    win->refine_input = gtk_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(win->refine_input), "e.g. Make it shorter, more formal, etc.");
    gtk_widget_set_hexpand(win->refine_input, TRUE);
    gtk_box_append(GTK_BOX(refine_box), win->refine_input);

    // Button row
    GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_halign(btn_box, GTK_ALIGN_END);
    gtk_box_append(GTK_BOX(vbox), btn_box);

    win->cancel_btn = gtk_button_new_with_label("❌ Cancel (use original)");
    gtk_box_append(GTK_BOX(btn_box), win->cancel_btn);

    win->refine_btn = gtk_button_new_with_label("🔄 Refine Again");
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

void yap_window_gtk_set_original_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->original_buffer, text, len);
}

void yap_window_gtk_set_refined_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->refined_buffer, text, len);
}

void yap_window_gtk_set_history_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->history_buffer, text, len);
}

void yap_window_gtk_set_revision(YapWindowGtk *win, int revision) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Revision: %d", revision);
    gtk_label_set_text(GTK_LABEL(win->revision_label), buf);
}

void yap_window_gtk_set_original_chars(YapWindowGtk *win, int chars) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Original: %d chars", chars);
    gtk_label_set_text(GTK_LABEL(win->original_chars_label), buf);
}

void yap_window_gtk_set_refined_chars(YapWindowGtk *win, int chars) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Refined: %d chars", chars);
    gtk_label_set_text(GTK_LABEL(win->refined_chars_label), buf);
}

void yap_window_gtk_set_compression(YapWindowGtk *win, float ratio) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Compression: %.0f%%", ratio * 100.0f);
    gtk_label_set_text(GTK_LABEL(win->compression_label), buf);
}

const char* yap_window_gtk_get_refine_input(YapWindowGtk *win) {
    GtkEntryBuffer *buffer = gtk_entry_get_buffer(GTK_ENTRY(win->refine_input));
    return gtk_entry_buffer_get_text(buffer);
}

void yap_window_gtk_clear_refine_input(YapWindowGtk *win) {
    gtk_editable_set_text(GTK_EDITABLE(win->refine_input), "");
}
