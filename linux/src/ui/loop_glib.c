#include "loop_glib.h"

#include <glib-unix.h>
#include <glib.h>
#include <gtk/gtk.h>

int talkies_ui_init(void) {
    if (gtk_is_initialized()) return 1;
    gdk_set_allowed_backends("x11,*");
    return gtk_init_check();
}

typedef struct {
    TalkiesLoopFn fn;
    void *user_data;
} Callback;

static gboolean on_fd(gint fd, GIOCondition condition, gpointer data) {
    (void)fd;
    (void)condition;
    Callback *cb = data;
    return cb->fn(cb->user_data) ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
}

static gboolean on_timeout(gpointer data) {
    Callback *cb = data;
    return cb->fn(cb->user_data) ? G_SOURCE_CONTINUE : G_SOURCE_REMOVE;
}

static Callback *callback_new(TalkiesLoopFn fn, void *user_data) {
    Callback *cb = g_new(Callback, 1);
    cb->fn = fn;
    cb->user_data = user_data;
    return cb;
}

unsigned talkies_loop_watch_fd(int fd, TalkiesLoopFn fn, void *user_data) {
    return g_unix_fd_add_full(G_PRIORITY_HIGH, fd, G_IO_IN | G_IO_HUP | G_IO_ERR, on_fd,
                              callback_new(fn, user_data), g_free);
}

unsigned talkies_loop_timeout(unsigned interval_ms, TalkiesLoopFn fn, void *user_data) {
    return g_timeout_add_full(G_PRIORITY_DEFAULT, interval_ms, on_timeout, callback_new(fn, user_data), g_free);
}

void talkies_loop_remove(unsigned source_id) {
    if (source_id) g_source_remove(source_id);
}

void talkies_loop_iterate(int may_block) {
    g_main_context_iteration(NULL, may_block ? TRUE : FALSE);
}
