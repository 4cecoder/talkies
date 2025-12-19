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
    void *user_data
);

// Text buffer operations
void yap_window_gtk_set_original_text(YapWindowGtk *win, const char *text, int len);
void yap_window_gtk_set_refined_text(YapWindowGtk *win, const char *text, int len);
void yap_window_gtk_set_history_text(YapWindowGtk *win, const char *text, int len);

// Label updates
void yap_window_gtk_set_revision(YapWindowGtk *win, int revision);
void yap_window_gtk_set_original_chars(YapWindowGtk *win, int chars);
void yap_window_gtk_set_refined_chars(YapWindowGtk *win, int chars);
void yap_window_gtk_set_compression(YapWindowGtk *win, float ratio);

// Input retrieval (returns internal pointer, do not free)
const char* yap_window_gtk_get_refine_input(YapWindowGtk *win);
void yap_window_gtk_clear_refine_input(YapWindowGtk *win);

#endif // YAP_WINDOW_GTK_H
