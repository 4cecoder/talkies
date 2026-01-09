#include "yap_window_gtk.h"
#include <gtk/gtk.h>
#include <string.h>

// Actual struct definition (not exposed in header)
struct YapWindowGtk {
    GtkWidget *window;
    GtkTextBuffer *context_buffer;       // Initial context input
    GtkTextBuffer *sandbox_buffer;       // Transcription sandbox (accumulates)
    GtkTextBuffer *revision_buffer;      // Current revision display
    GtkWidget *context_view;             // Editable context view
    GtkWidget *sandbox_view;             // Editable sandbox view
    GtkWidget *revision_view;            // Read-only revision view
    GtkWidget *sandbox_chars_label;
    GtkWidget *revision_nav_label;       // "Revision X of Y"
    GtkWidget *revision_stats_label;     // "123 chars"
    GtkWidget *prev_revision_btn;
    GtkWidget *next_revision_btn;
    GtkWidget *accept_btn;
    GtkWidget *refine_btn;
    GtkWidget *cancel_btn;
    GtkWidget *clear_context_btn;
    GtkWidget *clear_sandbox_btn;
    int current_revision_index;          // 0-based
    int total_revisions;
    void *user_data; // Points to Zig YapWindow struct

    // Part 2.5: Clarification section (between sandbox and revisions)
    GtkWidget *clarification_frame;      // Outer container
    GtkWidget *clarification_box;        // Vertical box for questions
    GtkWidget *clarification_label;      // Header label
    GtkWidget *question_boxes[3];        // Up to 3 question containers
    GtkWidget *question_labels[3];       // Question text
    GtkWidget *answer_buttons[3][4];     // Up to 4 answer buttons per question
    int question_count;                  // How many questions (1-3)
    int answers_remaining;               // Countdown until all answered
    void (*clarification_callback)(void*, void*);  // Answer callback
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

    // Apply Tokyo Night dark theme
    GtkCssProvider *css_provider = gtk_css_provider_new();
    const char *tokyo_night_css =
        "window {"
        "  background-color: #1a1b26;"
        "  color: #c0caf5;"
        "}"
        "label {"
        "  color: #c0caf5;"
        "}"
        "textview {"
        "  background-color: #24283b;"
        "  color: #c0caf5;"
        "  caret-color: #c0caf5;"
        "}"
        "textview text {"
        "  background-color: #24283b;"
        "  color: #c0caf5;"
        "}"
        "button {"
        "  background-color: #414868;"
        "  color: #c0caf5;"
        "  border: 1px solid #565f89;"
        "  border-radius: 4px;"
        "  padding: 6px 12px;"
        "}"
        "button:hover {"
        "  background-color: #565f89;"
        "}"
        "scrolledwindow {"
        "  background-color: #24283b;"
        "}"
        "frame {"
        "  border: 1px solid #565f89;"
        "  border-radius: 6px;"
        "  background-color: #1e2030;"
        "}"
        "separator {"
        "  background-color: #414868;"
        "  min-height: 1px;"
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

    // Header with stats
    GtkWidget *header_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_box_append(GTK_BOX(vbox), header_box);

    win->sandbox_chars_label = gtk_label_new("Sandbox: 0 chars");
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

    // === PART 2.5: Clarification Questions (initially hidden) ===
    win->clarification_frame = gtk_frame_new(NULL);
    gtk_widget_set_visible(win->clarification_frame, FALSE); // Hidden by default
    gtk_widget_set_margin_top(win->clarification_frame, 10);
    gtk_widget_set_margin_bottom(win->clarification_frame, 10);

    GtkWidget *clarification_content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_widget_set_margin_start(clarification_content, 12);
    gtk_widget_set_margin_end(clarification_content, 12);
    gtk_widget_set_margin_top(clarification_content, 12);
    gtk_widget_set_margin_bottom(clarification_content, 12);
    gtk_frame_set_child(GTK_FRAME(win->clarification_frame), clarification_content);

    win->clarification_label = gtk_label_new("🤔 Quick Questions (help me refine better)");
    gtk_widget_set_halign(win->clarification_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(clarification_content), win->clarification_label);

    // Separator
    GtkWidget *separator = gtk_separator_new(GTK_ORIENTATION_HORIZONTAL);
    gtk_box_append(GTK_BOX(clarification_content), separator);

    // Box for questions (will be populated dynamically)
    win->clarification_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    gtk_box_append(GTK_BOX(clarification_content), win->clarification_box);

    // Initialize question containers to NULL
    for (int i = 0; i < 3; i++) {
        win->question_boxes[i] = NULL;
        win->question_labels[i] = NULL;
        for (int j = 0; j < 4; j++) {
            win->answer_buttons[i][j] = NULL;
        }
    }
    win->question_count = 0;
    win->answers_remaining = 0;
    win->clarification_callback = NULL;

    // Add to main vbox AFTER sandbox, BEFORE revisions
    gtk_box_append(GTK_BOX(vbox), win->clarification_frame);

    // === PART 3: Navigable Revision Viewer (bottom section) ===
    GtkWidget *revision_header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_box_append(GTK_BOX(vbox), revision_header);

    GtkWidget *revision_label = gtk_label_new("📜 LLM Refinements");
    gtk_widget_set_hexpand(revision_label, TRUE);
    gtk_widget_set_halign(revision_label, GTK_ALIGN_START);
    gtk_box_append(GTK_BOX(revision_header), revision_label);

    // Navigation controls
    win->prev_revision_btn = gtk_button_new_with_label("◀ Previous");
    gtk_widget_set_sensitive(win->prev_revision_btn, FALSE);
    gtk_box_append(GTK_BOX(revision_header), win->prev_revision_btn);

    win->revision_nav_label = gtk_label_new("No revisions yet");
    gtk_box_append(GTK_BOX(revision_header), win->revision_nav_label);

    win->next_revision_btn = gtk_button_new_with_label("Next ▶");
    gtk_widget_set_sensitive(win->next_revision_btn, FALSE);
    gtk_box_append(GTK_BOX(revision_header), win->next_revision_btn);

    win->revision_stats_label = gtk_label_new("");
    gtk_box_append(GTK_BOX(revision_header), win->revision_stats_label);

    // Revision viewer (read-only)
    GtkWidget *revision_scroll = gtk_scrolled_window_new();
    gtk_widget_set_size_request(revision_scroll, -1, 150);
    win->revision_view = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(win->revision_view), FALSE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->revision_view), GTK_WRAP_WORD);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->revision_view), FALSE);
    win->revision_buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->revision_view));
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(revision_scroll), win->revision_view);
    gtk_box_append(GTK_BOX(vbox), revision_scroll);

    // Initialize state
    win->current_revision_index = 0;
    win->total_revisions = 0;

    // Button row
    GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_set_halign(btn_box, GTK_ALIGN_END);
    gtk_box_append(GTK_BOX(vbox), btn_box);

    win->cancel_btn = gtk_button_new_with_label("❌ Cancel");
    gtk_box_append(GTK_BOX(btn_box), win->cancel_btn);

    win->refine_btn = gtk_button_new_with_label("✨ Refine with LLM");
    gtk_box_append(GTK_BOX(btn_box), win->refine_btn);

    win->accept_btn = gtk_button_new_with_label("✅ Accept & Copy");
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
    void (*on_prev_revision)(void*),
    void (*on_next_revision)(void*),
    void *user_data
) {
    win->user_data = user_data;

    g_signal_connect_swapped(win->accept_btn, "clicked", G_CALLBACK(on_accept), user_data);
    g_signal_connect_swapped(win->refine_btn, "clicked", G_CALLBACK(on_refine), user_data);
    g_signal_connect_swapped(win->cancel_btn, "clicked", G_CALLBACK(on_cancel), user_data);
    g_signal_connect_swapped(win->prev_revision_btn, "clicked", G_CALLBACK(on_prev_revision), user_data);
    g_signal_connect_swapped(win->next_revision_btn, "clicked", G_CALLBACK(on_next_revision), user_data);
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

// Revision navigation management
void yap_window_gtk_set_revision_count(YapWindowGtk *win, int total) {
    win->total_revisions = total;

    // Update navigation label
    if (total == 0) {
        gtk_label_set_text(GTK_LABEL(win->revision_nav_label), "No revisions yet");
        gtk_widget_set_sensitive(win->prev_revision_btn, FALSE);
        gtk_widget_set_sensitive(win->next_revision_btn, FALSE);
        gtk_text_buffer_set_text(win->revision_buffer, "", -1);
        gtk_label_set_text(GTK_LABEL(win->revision_stats_label), "");
    } else {
        // Show latest revision by default
        win->current_revision_index = total - 1;
        char buf[64];
        snprintf(buf, sizeof(buf), "Revision %d of %d", win->current_revision_index + 1, total);
        gtk_label_set_text(GTK_LABEL(win->revision_nav_label), buf);

        // Update button states
        gtk_widget_set_sensitive(win->prev_revision_btn, win->current_revision_index > 0);
        gtk_widget_set_sensitive(win->next_revision_btn, win->current_revision_index < total - 1);
    }
}

void yap_window_gtk_set_current_revision_index(YapWindowGtk *win, int index) {
    if (index < 0 || index >= win->total_revisions) return;

    win->current_revision_index = index;

    // Update navigation label
    char buf[64];
    snprintf(buf, sizeof(buf), "Revision %d of %d", index + 1, win->total_revisions);
    gtk_label_set_text(GTK_LABEL(win->revision_nav_label), buf);

    // Update button states
    gtk_widget_set_sensitive(win->prev_revision_btn, index > 0);
    gtk_widget_set_sensitive(win->next_revision_btn, index < win->total_revisions - 1);
}

void yap_window_gtk_set_revision_text(YapWindowGtk *win, const char *text, int len) {
    gtk_text_buffer_set_text(win->revision_buffer, text, len);
}

void yap_window_gtk_set_revision_stats(YapWindowGtk *win, int chars, long timestamp) {
    char buf[128];
    snprintf(buf, sizeof(buf), "%d chars", chars);
    gtk_label_set_text(GTK_LABEL(win->revision_stats_label), buf);
}

void yap_window_gtk_set_sandbox_chars(YapWindowGtk *win, int chars) {
    char buf[64];
    snprintf(buf, sizeof(buf), "Sandbox: %d chars", chars);
    gtk_label_set_text(GTK_LABEL(win->sandbox_chars_label), buf);
}

// Clarification management (Part 2.5)
void yap_window_gtk_show_clarification(
    YapWindowGtk *win,
    YapClarificationQuestion *questions,
    int question_count
) {
    // Clear any previous questions
    for (int i = 0; i < 3; i++) {
        if (win->question_boxes[i]) {
            gtk_box_remove(GTK_BOX(win->clarification_box), win->question_boxes[i]);
            win->question_boxes[i] = NULL;
        }
    }

    win->question_count = question_count;
    win->answers_remaining = question_count;

    // Create UI for each question
    for (int q = 0; q < question_count && q < 3; q++) {
        YapClarificationQuestion *qdata = &questions[q];

        // Question container
        GtkWidget *qbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
        gtk_widget_set_margin_top(qbox, 8);
        win->question_boxes[q] = qbox;

        // Question label
        char label_buf[512];
        snprintf(label_buf, sizeof(label_buf), "Q%d: %s", q+1, qdata->question_text);
        win->question_labels[q] = gtk_label_new(label_buf);
        gtk_widget_set_halign(win->question_labels[q], GTK_ALIGN_START);
        gtk_label_set_wrap(GTK_LABEL(win->question_labels[q]), TRUE);
        gtk_box_append(GTK_BOX(qbox), win->question_labels[q]);

        // Answer buttons (horizontal box)
        GtkWidget *btn_box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        gtk_widget_set_halign(btn_box, GTK_ALIGN_START);
        gtk_box_append(GTK_BOX(qbox), btn_box);

        for (int opt = 0; opt < qdata->option_count && opt < 4; opt++) {
            GtkWidget *btn = gtk_button_new_with_label(qdata->options[opt]);
            win->answer_buttons[q][opt] = btn;

            // Store question_id and answer in button data
            g_object_set_data_full(
                G_OBJECT(btn),
                "question_id",
                g_strdup(qdata->id),
                g_free
            );
            g_object_set_data_full(
                G_OBJECT(btn),
                "answer",
                g_strdup(qdata->options[opt]),
                g_free
            );

            // Connect callback if set
            if (win->clarification_callback) {
                g_signal_connect(
                    btn,
                    "clicked",
                    G_CALLBACK(win->clarification_callback),
                    win->user_data
                );
            }

            gtk_box_append(GTK_BOX(btn_box), btn);
        }

        gtk_box_append(GTK_BOX(win->clarification_box), qbox);
    }

    // Show the frame
    gtk_widget_set_visible(win->clarification_frame, TRUE);
}

void yap_window_gtk_hide_clarification(YapWindowGtk *win) {
    gtk_widget_set_visible(win->clarification_frame, FALSE);
}

void yap_window_gtk_connect_clarification_callback(
    YapWindowGtk *win,
    void (*on_answer)(void*, void*),
    void *user_data
) {
    win->clarification_callback = on_answer;
    win->user_data = user_data;
}
