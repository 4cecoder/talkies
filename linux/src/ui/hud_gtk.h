#ifndef TALKIES_HUD_GTK_H
#define TALKIES_HUD_GTK_H

// Floating dictation panel: the Linux counterpart of the macOS DictationView.
//
// The panel lives at the top centre of the screen. It rests as a small
// waveform pill (124x38) and springs open to the full panel (560x184), the
// mini panel (360x126) or the transcript history (x420). The window itself
// never changes size: it is a fixed, transparent surface whose input region
// follows the drawn panel, so the expand/collapse animation needs no
// compositor round-trips and clicks outside the panel reach the windows
// underneath.
//
// All functions must be called on the GTK (main) thread and tolerate a NULL
// hud pointer.

typedef struct TalkiesHud TalkiesHud;

// Keep in sync with Stage in src/app/daemon.zig (new stages are appended).
typedef enum {
    TALKIES_HUD_IDLE = 0,
    TALKIES_HUD_LOADING_MODEL,
    TALKIES_HUD_RECORDING,
    TALKIES_HUD_TRANSCRIBING,
    TALKIES_HUD_CLEANING,
    TALKIES_HUD_ENHANCING_OLLAMA,
    TALKIES_HUD_ENHANCING_LM_STUDIO,
    TALKIES_HUD_INSERTING,
    TALKIES_HUD_COMPLETE,
    TALKIES_HUD_ERROR,
    TALKIES_HUD_NO_SPEECH,
    TALKIES_HUD_CLEANUP_FALLBACK,
    TALKIES_HUD_CLIPBOARD_FALLBACK,
} TalkiesHudStage;

typedef void (*TalkiesHudCallback)(void *user_data);

// Returns NULL when no display is available.
TalkiesHud *talkies_hud_new(void);
void talkies_hud_destroy(TalkiesHud *hud);

// Map / unmap the panel. Showing keeps the current collapsed/expanded state.
void talkies_hud_show(TalkiesHud *hud);
void talkies_hud_hide(TalkiesHud *hud);
int talkies_hud_is_visible(TalkiesHud *hud);

// Spring the panel open (1) or back to the waveform pill (0).
void talkies_hud_set_expanded(TalkiesHud *hud, int expanded);
int talkies_hud_is_expanded(TalkiesHud *hud);
// Compact 360x126 layout ("Use mini window" in Settings).
void talkies_hud_set_mini(TalkiesHud *hud, int mini);

// detail: error message (ERROR), manual-paste reason (CLIPBOARD_FALLBACK),
// or a hint override (COMPLETE, CLEANUP_FALLBACK). May be NULL.
void talkies_hud_set_stage(TalkiesHud *hud, TalkiesHudStage stage, const char *detail);
// Normalized 0..1 input level (dB-mapped, like macOS); appended to the
// scrolling 160-sample waveform history while recording.
void talkies_hud_set_level(TalkiesHud *hud, float level);
void talkies_hud_set_elapsed(TalkiesHud *hud, double seconds);
// Text of the latest dictation (Copy button, idle footer).
void talkies_hud_set_transcript(TalkiesHud *hud, const char *text);
// Adds an entry to the transcript history page (newest first).
void talkies_hud_add_history(TalkiesHud *hud, const char *text);
// e.g. "Right Alt" -> "Hold Right Alt for push-to-talk".
void talkies_hud_set_hotkey_name(TalkiesHud *hud, const char *name);
// A setup problem shown while idle instead of "Ready to dictate"
// (e.g. no audio server). NULL status clears it.
void talkies_hud_set_attention(TalkiesHud *hud, const char *status, const char *hint);

void talkies_hud_set_record_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data);
// Fired when the user collapses the panel (pointer leaves it, or a dismissable
// result is put away), so the daemon can return to idle.
void talkies_hud_set_dismiss_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data);

// Fixed window size and the panel's top margin within it; the daemon's
// Hyprland rules use these to anchor the window at the top centre.
#define TALKIES_HUD_WINDOW_WIDTH 624
#define TALKIES_HUD_WINDOW_HEIGHT 476
// The panel sits this far below the top of the screen, as on macOS.
#define TALKIES_HUD_SCREEN_TOP 34
#define TALKIES_HUD_PANEL_TOP 8

#endif
