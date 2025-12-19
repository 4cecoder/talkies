#ifndef DAEMON_STATUS_GTK_H
#define DAEMON_STATUS_GTK_H

#include <stddef.h>

// Opaque pointer - implementation details hidden in .c file
typedef struct DaemonStatusWindow DaemonStatusWindow;

// GTK initialization (call once at startup)
void daemon_status_gtk_init(void);

// Window lifecycle
DaemonStatusWindow* daemon_status_window_new(void);
void daemon_status_window_destroy(DaemonStatusWindow *win);
void daemon_status_window_show(DaemonStatusWindow *win);
void daemon_status_window_hide(DaemonStatusWindow *win);

// Status updates
void daemon_status_window_set_state(DaemonStatusWindow *win, const char *state);
void daemon_status_window_set_model(DaemonStatusWindow *win, const char *model);
void daemon_status_window_set_platform(DaemonStatusWindow *win, const char *platform);
void daemon_status_window_set_clients(DaemonStatusWindow *win, int count);
void daemon_status_window_set_yap_enabled(DaemonStatusWindow *win, int enabled);
void daemon_status_window_set_ollama_connected(DaemonStatusWindow *win, int connected);

// Activity updates
void daemon_status_window_set_activity(DaemonStatusWindow *win, const char *activity);
void daemon_status_window_set_last_transcription(DaemonStatusWindow *win, const char *time);

// Log management
typedef enum {
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_DEBUG
} LogLevel;

void daemon_status_window_add_log(DaemonStatusWindow *win, LogLevel level, const char *message);
void daemon_status_window_clear_logs(DaemonStatusWindow *win);

// Statistics
void daemon_status_window_set_stats(DaemonStatusWindow *win, int sessions, int errors, float avg_duration);

// Callbacks
void daemon_status_window_set_settings_callback(DaemonStatusWindow *win, void (*callback)(void*), void *user_data);

#endif // DAEMON_STATUS_GTK_H
