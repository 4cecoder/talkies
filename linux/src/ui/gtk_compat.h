#ifndef TALKIES_GTK_COMPAT_H
#define TALKIES_GTK_COMPAT_H

// Lets the UI build against GTK 4.6 (Ubuntu 22.04 / Debian 12 baseline),
// which release packages target, while using current APIs on newer GTK.

#include <gtk/gtk.h>

#if !GTK_CHECK_VERSION(4, 12, 0)
// 4.12 replaced load_from_data(provider, data, length) with load_from_string.
#define gtk_css_provider_load_from_string(provider, css) \
    gtk_css_provider_load_from_data((provider), (css), -1)
#endif

#include <dlfcn.h>

// gtk_check_button_set_child arrived in 4.8. Release builds compile against
// 4.6 headers, so resolve it at runtime: newer GTK gets the rich two-line
// radio rows, 4.6 falls back to a plain label. Returns FALSE when missing.
static inline gboolean talkies_check_button_set_child(GtkCheckButton *button, GtkWidget *child) {
    typedef void (*SetChildFn)(GtkCheckButton *, GtkWidget *);
    static SetChildFn set_child = NULL;
    static gboolean resolved = FALSE;
    if (!resolved) {
        set_child = (SetChildFn)dlsym(RTLD_DEFAULT, "gtk_check_button_set_child");
        resolved = TRUE;
    }
    if (!set_child) return FALSE;
    set_child(button, child);
    return TRUE;
}

#endif
