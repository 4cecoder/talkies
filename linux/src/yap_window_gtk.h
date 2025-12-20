#ifndef YAP_WINDOW_GTK_H
#define YAP_WINDOW_GTK_H

#include <stddef.h>
#include <string.h>

// Opaque pointer - implementation details hidden in .c file
typedef struct YapWindowGtk YapWindowGtk;

// GTK initialization (call once at startup)
void yap_window_gtk_init(void);

// GTK event loop - process pending events (call in tight loop)
void yap_window_gtk_process_events(void);

// Window lifecycle
YapWindowGtk* yap_window_gtk_new(void);
void yap_window_gtk_destroy(YapWindowGtk *win);
void yap_window_gtk_show(YapWindowGtk *win);
void yap_window_gtk_hide(YapWindowGtk *win);

// Signal connections
void yap_window_gtk_connect_signals(
    YapWindowGtk *win,
    void (*on_accept)(void*),
    void (*on_refine)(void*),
    void (*on_cancel)(void*),
    void (*on_prev_revision)(void*),
    void (*on_next_revision)(void*),
    void *user_data
);

// Context management (Part 1: Initial Context)
void yap_window_gtk_set_context_text(YapWindowGtk *win, const char *text, int len);
const char* yap_window_gtk_get_context_text(YapWindowGtk *win);
void yap_window_gtk_clear_context(YapWindowGtk *win);

// Sandbox management (Part 2: Transcription Sandbox)
void yap_window_gtk_set_sandbox_text(YapWindowGtk *win, const char *text, int len);
void yap_window_gtk_append_sandbox_text(YapWindowGtk *win, const char *text, int len);
const char* yap_window_gtk_get_sandbox_text(YapWindowGtk *win);
void yap_window_gtk_clear_sandbox(YapWindowGtk *win);

// History management (Part 3: Navigable Revision Viewer)
void yap_window_gtk_set_revision_count(YapWindowGtk *win, int total);
void yap_window_gtk_set_current_revision_index(YapWindowGtk *win, int index);
void yap_window_gtk_set_revision_text(YapWindowGtk *win, const char *text, int len);
void yap_window_gtk_set_revision_stats(YapWindowGtk *win, int chars, long timestamp);

// Stats
void yap_window_gtk_set_sandbox_chars(YapWindowGtk *win, int chars);

#endif // YAP_WINDOW_GTK_H
