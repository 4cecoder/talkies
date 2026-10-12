#ifndef TALKIES_TRAY_SNI_H
#define TALKIES_TRAY_SNI_H

// System tray icon via the freedesktop StatusNotifierItem protocol plus a
// com.canonical.dbusmenu menu (KDE, waybar, GNOME with AppIndicator ext,
// Hyprland bars...). The Linux counterpart of the macOS menu bar item:
// left click toggles the dictation window, the menu offers Open / Record /
// Settings / Quit. Non-blocking: call talkies_tray_process() from the main loop.

typedef struct TalkiesTray TalkiesTray;

typedef enum {
    TALKIES_TRAY_ACTIVATE = 0,   // primary click
    TALKIES_TRAY_OPEN,           // "Open Talkies"
    TALKIES_TRAY_TOGGLE_RECORD,  // "Start/Stop Recording"
    TALKIES_TRAY_SETTINGS,       // "Settings..."
    TALKIES_TRAY_QUIT,           // "Quit Talkies"
} TalkiesTrayAction;

typedef void (*TalkiesTrayCallback)(TalkiesTrayAction action, void *user_data);

// Returns NULL if the session bus is unavailable. A missing tray host is not
// an error: the item registers automatically once a watcher appears.
TalkiesTray *talkies_tray_new(TalkiesTrayCallback callback, void *user_data);
void talkies_tray_destroy(TalkiesTray *tray);

// Dispatch pending D-Bus messages without blocking.
void talkies_tray_process(TalkiesTray *tray);
// Socket to watch for readability; call talkies_tray_process when it fires.
int talkies_tray_get_fd(TalkiesTray *tray);

// Reflect recording state in icon, tooltip and menu label.
void talkies_tray_set_recording(TalkiesTray *tray, int recording);
void talkies_tray_set_status_text(TalkiesTray *tray, const char *text);

#endif
