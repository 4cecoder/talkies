#ifndef TALKIES_SETTINGS_GTK_H
#define TALKIES_SETTINGS_GTK_H

// Settings window written against the GTK4 C API directly (the zig-gobject
// bindings it used to depend on do not build on Zig >= 0.16). Mirrors the
// macOS SettingsView: General / Transcription / Enhancement (Ollama, LM
// Studio, S1-mini) / Output / Advanced, auto-saving 0.5s after each change.
// All functions must be called on the GTK (main) thread.

typedef struct TalkiesSettingsWindow TalkiesSettingsWindow;

// Keep in sync with SettingsData in src/settings_window.zig.
typedef struct {
    // General
    double push_to_talk_threshold;
    int show_hud;
    int voice_assistant_mode;
    int insert_text_in_assistant_mode;

    // Audio + transcription
    char audio_device[256];
    char model[32];
    char language[16];
    char vocabulary_prompt[512];

    // Enhancement: 0=none 1=s1_mini 2=ollama 3=lm_studio
    int enhancer;

    char ollama_host[256];
    char ollama_model[256];
    int ollama_mode; // 0..4, see Mode in src/enhance.zig
    double ollama_temperature;
    double ollama_top_p;
    int ollama_top_k;
    double ollama_repeat_penalty;
    int ollama_context_length;
    int ollama_max_tokens;
    int ollama_use_custom_prompt;
    char ollama_custom_prompt[4096];
    char ollama_stop_sequences[256];

    char lm_studio_endpoint[256];
    char lm_studio_model[256];
    int lm_studio_mode;
    double lm_studio_temperature;
    double lm_studio_top_p;
    int lm_studio_max_tokens;

    // Output
    int auto_paste;
    int restore_clipboard;
    char paste_keybind[32];

    // Advanced
    int vad_enabled;
    int vad_mode;
    int show_status_gui;
} TalkiesSettingsData;

typedef enum {
    TALKIES_SERVER_OLLAMA = 0,
    TALKIES_SERVER_LM_STUDIO = 1,
} TalkiesServer;

typedef void (*TalkiesSettingsSaveFn)(const TalkiesSettingsData *data, void *user_data);
typedef void (*TalkiesSettingsRefreshFn)(TalkiesServer server, const char *base_url, void *user_data);

// mode_names/mode_descriptions: 5 entries each, owned by the caller (static).
TalkiesSettingsWindow *talkies_settings_window_new(const char *const *mode_names,
                                                   const char *const *mode_descriptions,
                                                   const char *config_path);
void talkies_settings_window_destroy(TalkiesSettingsWindow *win);

void talkies_settings_window_set_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsSaveFn on_save,
                                           TalkiesSettingsRefreshFn on_refresh, void *user_data);

// Populate widgets from data and present the window.
void talkies_settings_window_present(TalkiesSettingsWindow *win, const TalkiesSettingsData *data);

// Input devices: names are PulseAudio source names; descriptions are shown.
void talkies_settings_window_set_audio_devices(TalkiesSettingsWindow *win, const char *const *names,
                                               const char *const *descriptions, int count);

// Model list for a server; status is shown next to the refresh button.
void talkies_settings_window_set_models(TalkiesSettingsWindow *win, TalkiesServer server,
                                        const char *const *models, int count, const char *status);

#endif
