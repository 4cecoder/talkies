#ifndef TALKIES_SETTINGS_GTK_H
#define TALKIES_SETTINGS_GTK_H

// Settings window written against the GTK4 C API directly (the zig-gobject
// bindings it used to depend on do not build on Zig >= 0.16). Mirrors the
// macOS SettingsView: General / Transcription / Enhancement (Ollama, LM
// Studio, S1-mini) / Output / Advanced, auto-saving 0.5s after each change.
// All functions must be called on the GTK (main) thread.

typedef struct TalkiesSettingsWindow TalkiesSettingsWindow;

// Translated for Zig by the build (c_settings); mapped in src/app/daemon.zig.
typedef struct {
    // General
    double push_to_talk_threshold; // seconds
    int show_hud;
    int mini_window;
    int launch_at_login;
    int voice_assistant_mode;
    int insert_text_in_assistant_mode;
    int save_history;

    // Audio + transcription
    char audio_device[256];
    // Recognizer: 0=auto (Phonon-2, Whisper fallback) 1=phonon 2=whisper
    int speech_engine;
    char model[32]; // Whisper model
    char language[16];
    char vocabulary_prompt[512]; // comma-separated (one term per line in the UI)

    // Enhancement: 0=none 1=s1_mini 2=ollama 3=lm_studio
    int enhancer;
    // S1-mini output: style 0=casual 1=semi_casual 2=semi_formal,
    // structure 0=prose 1=lists, context 0=general 1=email
    int cleanup_style;
    int cleanup_structure;
    int cleanup_context;

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

// S1-mini on-device model management (Enhancement > S1-mini page).
typedef enum {
    TALKIES_S1_MISSING = 0,
    TALKIES_S1_DOWNLOADING = 1,
    TALKIES_S1_READY = 2,
    TALKIES_S1_FAILED = 3,
} TalkiesS1State;

typedef void (*TalkiesSettingsActionFn)(void *user_data);

void talkies_settings_window_set_s1_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsActionFn on_download,
                                              TalkiesSettingsActionFn on_remove);
// fraction: 0..1 while downloading. detail: optional extra text (errors).
void talkies_settings_window_set_s1_state(TalkiesSettingsWindow *win, TalkiesS1State state, double fraction,
                                          const char *detail);

// Phonon-2 recognizer model (Transcription page). Same states as S1-mini;
// detail is shown when Phonon-2 is installed but could not load.
void talkies_settings_window_set_phonon_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsActionFn on_download,
                                                  TalkiesSettingsActionFn on_remove);
void talkies_settings_window_set_phonon_state(TalkiesSettingsWindow *win, TalkiesS1State state, double fraction,
                                              const char *detail);

// System status (General page): one summary line, details on demand.
typedef enum { TALKIES_HEALTH_OK = 0, TALKIES_HEALTH_WARN = 1, TALKIES_HEALTH_FAIL = 2 } TalkiesHealthLevel;

typedef struct {
    TalkiesHealthLevel level;
    const char *title;
    const char *detail;
    const char *fix; // may be empty
} TalkiesHealthItem;

void talkies_settings_window_set_health(TalkiesSettingsWindow *win, const TalkiesHealthItem *items, int count);

#endif
