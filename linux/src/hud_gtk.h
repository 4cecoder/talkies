#ifndef TALKIES_HUD_GTK_H
#define TALKIES_HUD_GTK_H

// Floating dictation HUD: the Linux counterpart of the macOS DictationView.
// A 520x140 borderless window with an animated gradient backdrop, a status
// dot + label, a record button, a 60-bar live waveform and a one-line
// pipeline/transcript footer. All functions must be called on the GTK
// (main) thread and tolerate a NULL hud pointer.

typedef struct TalkiesHud TalkiesHud;

// Keep in sync with HudStage in src/hud.zig.
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
} TalkiesHudStage;

typedef void (*TalkiesHudCallback)(void *user_data);

// Returns NULL when no display is available.
TalkiesHud *talkies_hud_new(void);
void talkies_hud_destroy(TalkiesHud *hud);

void talkies_hud_show(TalkiesHud *hud);
void talkies_hud_hide(TalkiesHud *hud);
int talkies_hud_is_visible(TalkiesHud *hud);

// detail is shown for TALKIES_HUD_ERROR; may be NULL.
void talkies_hud_set_stage(TalkiesHud *hud, TalkiesHudStage stage, const char *detail);
// Normalized 0..1 input level (dB-mapped, like macOS).
void talkies_hud_set_level(TalkiesHud *hud, float level);
void talkies_hud_set_elapsed(TalkiesHud *hud, double seconds);
void talkies_hud_set_transcript(TalkiesHud *hud, const char *text);
// e.g. "Right Alt" -> idle text "Press Right Alt to start".
void talkies_hud_set_hotkey_name(TalkiesHud *hud, const char *name);
void talkies_hud_set_record_callback(TalkiesHud *hud, TalkiesHudCallback callback, void *user_data);

#endif
