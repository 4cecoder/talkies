#include "settings_gtk.h"

#include <gtk/gtk.h>
#include <string.h>

#define MODE_COUNT 5
#define SAVE_DEBOUNCE_MS 500

static const char *const whisper_models[] = {"tiny", "base", "small", "medium", "large", NULL};
static const char *const enhancer_names[] = {"Off", "S1-mini (on-device)", "Ollama", "LM Studio", NULL};
static const char *const paste_keybinds[] = {"ctrl+v", "ctrl+shift+v", "shift+Insert", NULL};
static const char *const vad_modes[] = {"Quality", "Low bitrate", "Aggressive", "Very aggressive", NULL};

typedef struct {
    GtkWidget *dropdown;
    GtkStringList *list;
    GtkWidget *status;
    GtkWidget *url_entry;
    char *wanted; // model to select once the list arrives
} ModelPicker;

struct TalkiesSettingsWindow {
    GtkWidget *window;
    const char *const *mode_names;
    const char *const *mode_descriptions;

    // General
    GtkWidget *threshold;
    GtkWidget *show_hud;
    GtkWidget *voice_assistant;
    GtkWidget *assistant_insert;

    // Transcription
    GtkWidget *audio_device;
    GtkStringList *audio_device_list;
    GPtrArray *audio_device_names; // char*, index-aligned with the list
    GtkWidget *model;
    GtkWidget *language;
    GtkWidget *vocabulary;

    // Enhancement
    GtkWidget *enhancer;
    GtkWidget *enhancer_stack;

    GtkWidget *s1_status;
    GtkWidget *s1_progress;
    GtkWidget *s1_download;
    GtkWidget *s1_remove;
    TalkiesSettingsActionFn on_s1_download;
    TalkiesSettingsActionFn on_s1_remove;

    ModelPicker ollama_models;
    GtkWidget *ollama_mode;
    GtkWidget *ollama_mode_desc;
    GtkWidget *ollama_temperature;
    GtkWidget *ollama_top_p;
    GtkWidget *ollama_top_k;
    GtkWidget *ollama_repeat_penalty;
    GtkWidget *ollama_context;
    GtkWidget *ollama_max_tokens;
    GtkWidget *ollama_use_custom;
    GtkWidget *ollama_custom_prompt;
    GtkWidget *ollama_stop;

    ModelPicker lm_models;
    GtkWidget *lm_mode;
    GtkWidget *lm_mode_desc;
    GtkWidget *lm_temperature;
    GtkWidget *lm_top_p;
    GtkWidget *lm_max_tokens;

    // Output
    GtkWidget *auto_paste;
    GtkWidget *restore_clipboard;
    GtkWidget *paste_keybind;

    // Advanced
    GtkWidget *vad_enabled;
    GtkWidget *vad_mode;
    GtkWidget *show_status_gui;

    gboolean populating;
    guint save_source;
    TalkiesSettingsSaveFn on_save;
    TalkiesSettingsRefreshFn on_refresh;
    void *user_data;
};

// ---------------------------------------------------------------------------
// Auto-save
// ---------------------------------------------------------------------------

static void copy_text(char *dst, size_t size, const char *src) {
    g_strlcpy(dst, src ? src : "", size);
}

static const char *dropdown_string(GtkWidget *dropdown) {
    GObject *item = gtk_drop_down_get_selected_item(GTK_DROP_DOWN(dropdown));
    return item ? gtk_string_object_get_string(GTK_STRING_OBJECT(item)) : "";
}

static int dropdown_index(GtkWidget *dropdown) {
    guint selected = gtk_drop_down_get_selected(GTK_DROP_DOWN(dropdown));
    return selected == GTK_INVALID_LIST_POSITION ? 0 : (int)selected;
}

static double scale_value(GtkWidget *scale) {
    return gtk_range_get_value(GTK_RANGE(scale));
}

static void collect(TalkiesSettingsWindow *win, TalkiesSettingsData *d) {
    memset(d, 0, sizeof *d);
    d->push_to_talk_threshold = scale_value(win->threshold);
    d->show_hud = gtk_switch_get_active(GTK_SWITCH(win->show_hud));
    d->voice_assistant_mode = gtk_switch_get_active(GTK_SWITCH(win->voice_assistant));
    d->insert_text_in_assistant_mode = gtk_switch_get_active(GTK_SWITCH(win->assistant_insert));

    int device = dropdown_index(win->audio_device);
    const char *device_name = (guint)device < win->audio_device_names->len
                                  ? g_ptr_array_index(win->audio_device_names, device)
                                  : "";
    copy_text(d->audio_device, sizeof d->audio_device, device_name);
    copy_text(d->model, sizeof d->model, dropdown_string(win->model));
    copy_text(d->language, sizeof d->language, gtk_editable_get_text(GTK_EDITABLE(win->language)));
    copy_text(d->vocabulary_prompt, sizeof d->vocabulary_prompt, gtk_editable_get_text(GTK_EDITABLE(win->vocabulary)));

    d->enhancer = dropdown_index(win->enhancer);

    copy_text(d->ollama_host, sizeof d->ollama_host, gtk_editable_get_text(GTK_EDITABLE(win->ollama_models.url_entry)));
    copy_text(d->ollama_model, sizeof d->ollama_model, dropdown_string(win->ollama_models.dropdown));
    d->ollama_mode = dropdown_index(win->ollama_mode);
    d->ollama_temperature = scale_value(win->ollama_temperature);
    d->ollama_top_p = scale_value(win->ollama_top_p);
    d->ollama_top_k = (int)scale_value(win->ollama_top_k);
    d->ollama_repeat_penalty = scale_value(win->ollama_repeat_penalty);
    d->ollama_context_length = (int)scale_value(win->ollama_context);
    d->ollama_max_tokens = (int)scale_value(win->ollama_max_tokens);
    d->ollama_use_custom_prompt = gtk_switch_get_active(GTK_SWITCH(win->ollama_use_custom));
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->ollama_custom_prompt));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    char *prompt = gtk_text_buffer_get_text(buffer, &start, &end, FALSE);
    copy_text(d->ollama_custom_prompt, sizeof d->ollama_custom_prompt, prompt);
    g_free(prompt);
    copy_text(d->ollama_stop_sequences, sizeof d->ollama_stop_sequences, gtk_editable_get_text(GTK_EDITABLE(win->ollama_stop)));

    copy_text(d->lm_studio_endpoint, sizeof d->lm_studio_endpoint, gtk_editable_get_text(GTK_EDITABLE(win->lm_models.url_entry)));
    copy_text(d->lm_studio_model, sizeof d->lm_studio_model, dropdown_string(win->lm_models.dropdown));
    d->lm_studio_mode = dropdown_index(win->lm_mode);
    d->lm_studio_temperature = scale_value(win->lm_temperature);
    d->lm_studio_top_p = scale_value(win->lm_top_p);
    d->lm_studio_max_tokens = (int)scale_value(win->lm_max_tokens);

    d->auto_paste = gtk_switch_get_active(GTK_SWITCH(win->auto_paste));
    d->restore_clipboard = gtk_switch_get_active(GTK_SWITCH(win->restore_clipboard));
    copy_text(d->paste_keybind, sizeof d->paste_keybind, dropdown_string(win->paste_keybind));

    d->vad_enabled = gtk_switch_get_active(GTK_SWITCH(win->vad_enabled));
    d->vad_mode = dropdown_index(win->vad_mode);
    d->show_status_gui = gtk_switch_get_active(GTK_SWITCH(win->show_status_gui));
}

static gboolean save_now(gpointer user_data) {
    TalkiesSettingsWindow *win = user_data;
    win->save_source = 0;
    if (win->on_save) {
        TalkiesSettingsData data;
        collect(win, &data);
        win->on_save(&data, win->user_data);
    }
    return G_SOURCE_REMOVE;
}

static void schedule_save(TalkiesSettingsWindow *win) {
    if (win->populating) return;
    if (win->save_source) g_source_remove(win->save_source);
    win->save_source = g_timeout_add(SAVE_DEBOUNCE_MS, save_now, win);
}

static void on_changed(GObject *object, GParamSpec *pspec, gpointer user_data) {
    (void)object;
    (void)pspec;
    schedule_save(user_data);
}

static void on_signal_changed(gpointer instance, gpointer user_data) {
    (void)instance;
    schedule_save(user_data);
}

// ---------------------------------------------------------------------------
// Widget helpers
// ---------------------------------------------------------------------------

static GtkWidget *page_new(GtkWidget *stack, const char *name, const char *title, GtkWidget **out_box) {
    GtkWidget *scroller = gtk_scrolled_window_new();
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroller), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_widget_set_margin_start(box, 24);
    gtk_widget_set_margin_end(box, 24);
    gtk_widget_set_margin_top(box, 18);
    gtk_widget_set_margin_bottom(box, 18);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), box);
    gtk_stack_add_titled(GTK_STACK(stack), scroller, name, title);
    *out_box = box;
    return scroller;
}

static void add_section(GtkWidget *box, const char *title) {
    GtkWidget *label = gtk_label_new(title);
    gtk_widget_add_css_class(label, "heading");
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_widget_set_margin_top(label, 12);
    gtk_box_append(GTK_BOX(box), label);
}

static void add_note(GtkWidget *box, const char *text) {
    GtkWidget *label = gtk_label_new(text);
    gtk_widget_add_css_class(label, "dim-label");
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_label_set_wrap(GTK_LABEL(label), TRUE);
    gtk_box_append(GTK_BOX(box), label);
}

static void add_row(GtkWidget *box, const char *title, const char *subtitle, GtkWidget *control) {
    GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    GtkWidget *labels = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    gtk_widget_set_hexpand(labels, TRUE);
    GtkWidget *title_label = gtk_label_new(title);
    gtk_label_set_xalign(GTK_LABEL(title_label), 0);
    gtk_box_append(GTK_BOX(labels), title_label);
    if (subtitle) {
        GtkWidget *sub = gtk_label_new(subtitle);
        gtk_widget_add_css_class(sub, "dim-label");
        gtk_widget_add_css_class(sub, "caption");
        gtk_label_set_xalign(GTK_LABEL(sub), 0);
        gtk_label_set_wrap(GTK_LABEL(sub), TRUE);
        gtk_box_append(GTK_BOX(labels), sub);
    }
    gtk_widget_set_valign(control, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(row), labels);
    gtk_box_append(GTK_BOX(row), control);
    gtk_box_append(GTK_BOX(box), row);
}

static GtkWidget *switch_new(TalkiesSettingsWindow *win) {
    GtkWidget *w = gtk_switch_new();
    g_signal_connect(w, "notify::active", G_CALLBACK(on_changed), win);
    return w;
}

static GtkWidget *scale_new(TalkiesSettingsWindow *win, double min, double max, double step, int digits) {
    GtkWidget *w = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, min, max, step);
    gtk_scale_set_digits(GTK_SCALE(w), digits);
    gtk_scale_set_draw_value(GTK_SCALE(w), TRUE);
    gtk_scale_set_value_pos(GTK_SCALE(w), GTK_POS_RIGHT);
    gtk_widget_set_size_request(w, 220, -1);
    g_signal_connect(w, "value-changed", G_CALLBACK(on_signal_changed), win);
    return w;
}

static GtkWidget *entry_new(TalkiesSettingsWindow *win, const char *placeholder, int width) {
    GtkWidget *w = gtk_entry_new();
    if (placeholder) gtk_entry_set_placeholder_text(GTK_ENTRY(w), placeholder);
    gtk_widget_set_size_request(w, width, -1);
    g_signal_connect(w, "changed", G_CALLBACK(on_signal_changed), win);
    return w;
}

static GtkWidget *dropdown_new(TalkiesSettingsWindow *win, const char *const *items) {
    GtkWidget *w = gtk_drop_down_new_from_strings(items);
    g_signal_connect(w, "notify::selected", G_CALLBACK(on_changed), win);
    return w;
}

static void dropdown_select_string(GtkWidget *dropdown, const char *value) {
    GListModel *model = gtk_drop_down_get_model(GTK_DROP_DOWN(dropdown));
    guint n = g_list_model_get_n_items(model);
    for (guint i = 0; i < n; i++) {
        GtkStringObject *item = g_list_model_get_item(model, i);
        gboolean match = g_strcmp0(gtk_string_object_get_string(item), value) == 0;
        g_object_unref(item);
        if (match) {
            gtk_drop_down_set_selected(GTK_DROP_DOWN(dropdown), i);
            return;
        }
    }
}

// ---------------------------------------------------------------------------
// Model pickers
// ---------------------------------------------------------------------------

typedef struct {
    TalkiesSettingsWindow *win;
    TalkiesServer server;
} RefreshContext;

static void on_refresh_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    RefreshContext *ctx = user_data;
    ModelPicker *picker = ctx->server == TALKIES_SERVER_OLLAMA ? &ctx->win->ollama_models : &ctx->win->lm_models;
    gtk_label_set_text(GTK_LABEL(picker->status), "Checking...");
    if (ctx->win->on_refresh) {
        ctx->win->on_refresh(ctx->server, gtk_editable_get_text(GTK_EDITABLE(picker->url_entry)), ctx->win->user_data);
    }
}

static void build_model_picker(TalkiesSettingsWindow *win, GtkWidget *box, ModelPicker *picker, TalkiesServer server,
                               const char *url_title, const char *url_placeholder) {
    add_section(box, "Server");
    picker->url_entry = entry_new(win, url_placeholder, 260);
    add_row(box, url_title, "Local only: transcripts never leave this machine", picker->url_entry);

    picker->list = gtk_string_list_new(NULL);
    picker->dropdown = gtk_drop_down_new(G_LIST_MODEL(picker->list), NULL);
    gtk_widget_set_size_request(picker->dropdown, 260, -1);
    g_signal_connect(picker->dropdown, "notify::selected", G_CALLBACK(on_changed), win);

    GtkWidget *refresh = gtk_button_new_from_icon_name("view-refresh-symbolic");
    gtk_widget_set_tooltip_text(refresh, "Check server and reload models");
    RefreshContext *ctx = g_new0(RefreshContext, 1);
    ctx->win = win;
    ctx->server = server;
    g_signal_connect_data(refresh, "clicked", G_CALLBACK(on_refresh_clicked), ctx, (GClosureNotify)g_free, 0);

    GtkWidget *model_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    gtk_box_append(GTK_BOX(model_row), picker->dropdown);
    gtk_box_append(GTK_BOX(model_row), refresh);
    add_row(box, "Model", NULL, model_row);

    picker->status = gtk_label_new("Not checked yet");
    gtk_widget_add_css_class(picker->status, "dim-label");
    gtk_label_set_xalign(GTK_LABEL(picker->status), 1);
    gtk_box_append(GTK_BOX(box), picker->status);
}

static void picker_set_models(TalkiesSettingsWindow *win, ModelPicker *picker, const char *const *models, int count) {
    const char *current = dropdown_string(picker->dropdown);
    char *keep = g_strdup(picker->wanted ? picker->wanted : current);

    gboolean was_populating = win->populating;
    win->populating = TRUE;
    guint old = g_list_model_get_n_items(G_LIST_MODEL(picker->list));
    gtk_string_list_splice(picker->list, 0, old, NULL);
    gboolean found = FALSE;
    for (int i = 0; i < count; i++) {
        gtk_string_list_append(picker->list, models[i]);
        if (g_strcmp0(models[i], keep) == 0) found = TRUE;
    }
    // Keep a configured model selectable even if the server doesn't list it.
    if (!found && keep && keep[0]) gtk_string_list_splice(picker->list, 0, 0, (const char *const[]){keep, NULL});
    if (keep && keep[0]) {
        dropdown_select_string(picker->dropdown, keep);
    } else if (count > 0) {
        gtk_drop_down_set_selected(GTK_DROP_DOWN(picker->dropdown), 0);
    }
    win->populating = was_populating;
    g_free(keep);
    g_clear_pointer(&picker->wanted, g_free);
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

static void update_mode_descriptions(TalkiesSettingsWindow *win) {
    gtk_label_set_text(GTK_LABEL(win->ollama_mode_desc), win->mode_descriptions[dropdown_index(win->ollama_mode)]);
    gtk_label_set_text(GTK_LABEL(win->lm_mode_desc), win->mode_descriptions[dropdown_index(win->lm_mode)]);
}

static void on_mode_changed(GObject *object, GParamSpec *pspec, gpointer user_data) {
    (void)object;
    (void)pspec;
    update_mode_descriptions(user_data);
}

static void on_enhancer_changed(GObject *object, GParamSpec *pspec, gpointer user_data) {
    (void)object;
    (void)pspec;
    TalkiesSettingsWindow *win = user_data;
    static const char *const pages[] = {"none", "s1_mini", "ollama", "lm_studio"};
    gtk_stack_set_visible_child_name(GTK_STACK(win->enhancer_stack), pages[dropdown_index(win->enhancer)]);
}

static GtkWidget *mode_picker(TalkiesSettingsWindow *win, GtkWidget *box, GtkWidget **dropdown, GtkWidget **desc) {
    const char *names[MODE_COUNT + 1];
    for (int i = 0; i < MODE_COUNT; i++) names[i] = win->mode_names[i];
    names[MODE_COUNT] = NULL;
    *dropdown = dropdown_new(win, names);
    g_signal_connect(*dropdown, "notify::selected", G_CALLBACK(on_mode_changed), win);
    add_section(box, "Enhancement Mode");
    add_row(box, "Mode", NULL, *dropdown);
    *desc = gtk_label_new("");
    gtk_widget_add_css_class(*desc, "dim-label");
    gtk_label_set_xalign(GTK_LABEL(*desc), 0);
    gtk_label_set_wrap(GTK_LABEL(*desc), TRUE);
    gtk_box_append(GTK_BOX(box), *desc);
    return *dropdown;
}

static void on_ollama_reset(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    gtk_range_set_value(GTK_RANGE(win->ollama_temperature), 0.3);
    gtk_range_set_value(GTK_RANGE(win->ollama_top_p), 0.9);
    gtk_range_set_value(GTK_RANGE(win->ollama_top_k), 40);
    gtk_range_set_value(GTK_RANGE(win->ollama_repeat_penalty), 1.1);
    gtk_range_set_value(GTK_RANGE(win->ollama_context), 2048);
    gtk_range_set_value(GTK_RANGE(win->ollama_max_tokens), 500);
}

static void on_lm_reset(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    gtk_range_set_value(GTK_RANGE(win->lm_temperature), 0.3);
    gtk_range_set_value(GTK_RANGE(win->lm_top_p), 0.9);
    gtk_range_set_value(GTK_RANGE(win->lm_max_tokens), 4096);
}

static void on_s1_download_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    if (win->on_s1_download) win->on_s1_download(win->user_data);
}

static void on_s1_remove_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    if (win->on_s1_remove) win->on_s1_remove(win->user_data);
}

static GtkWidget *provider_page(void) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    return box;
}

static void build_enhancement_page(TalkiesSettingsWindow *win, GtkWidget *box) {
    add_section(box, "Text Enhancement");
    win->enhancer = dropdown_new(win, enhancer_names);
    g_signal_connect(win->enhancer, "notify::selected", G_CALLBACK(on_enhancer_changed), win);
    add_row(box, "Enhancer", "Post-process each transcript before it is inserted", win->enhancer);

    win->enhancer_stack = gtk_stack_new();
    gtk_stack_set_vhomogeneous(GTK_STACK(win->enhancer_stack), FALSE);
    gtk_box_append(GTK_BOX(box), win->enhancer_stack);

    GtkWidget *none = provider_page();
    add_note(none, "Transcripts are inserted exactly as Whisper produced them.");
    gtk_stack_add_named(GTK_STACK(win->enhancer_stack), none, "none");

    GtkWidget *s1 = provider_page();
    add_note(s1, "S1-mini runs fully on-device (llama.cpp on the CPU) and fixes punctuation, "
                 "capitalization and filler words. Until the model is installed, transcripts are "
                 "inserted unchanged.");
    add_section(s1, "Model");
    win->s1_status = gtk_label_new("Checking...");
    gtk_label_set_xalign(GTK_LABEL(win->s1_status), 0);
    gtk_label_set_wrap(GTK_LABEL(win->s1_status), TRUE);
    gtk_widget_set_hexpand(win->s1_status, TRUE);
    win->s1_download = gtk_button_new_with_label("Download (484 MB)");
    gtk_widget_add_css_class(win->s1_download, "suggested-action");
    g_signal_connect(win->s1_download, "clicked", G_CALLBACK(on_s1_download_clicked), win);
    win->s1_remove = gtk_button_new_with_label("Remove");
    gtk_widget_add_css_class(win->s1_remove, "destructive-action");
    g_signal_connect(win->s1_remove, "clicked", G_CALLBACK(on_s1_remove_clicked), win);
    GtkWidget *s1_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_append(GTK_BOX(s1_row), win->s1_status);
    gtk_box_append(GTK_BOX(s1_row), win->s1_download);
    gtk_box_append(GTK_BOX(s1_row), win->s1_remove);
    gtk_box_append(GTK_BOX(s1), s1_row);
    win->s1_progress = gtk_progress_bar_new();
    gtk_widget_set_visible(win->s1_progress, FALSE);
    gtk_box_append(GTK_BOX(s1), win->s1_progress);
    add_note(s1, "Pinned superwhisper/s1-mini-GGUF (q4_k_m), SHA-256 verified. Stored in "
                 "~/.local/share/talkies/models.");
    gtk_stack_add_named(GTK_STACK(win->enhancer_stack), s1, "s1_mini");

    // Ollama
    GtkWidget *ol = provider_page();
    build_model_picker(win, ol, &win->ollama_models, TALKIES_SERVER_OLLAMA, "Host", "http://localhost:11434");
    mode_picker(win, ol, &win->ollama_mode, &win->ollama_mode_desc);
    add_section(ol, "LLM Parameters");
    win->ollama_temperature = scale_new(win, 0, 2, 0.05, 2);
    add_row(ol, "Temperature", "Higher is more creative", win->ollama_temperature);
    win->ollama_top_p = scale_new(win, 0, 1, 0.05, 2);
    add_row(ol, "Top P", NULL, win->ollama_top_p);
    win->ollama_top_k = scale_new(win, 0, 100, 1, 0);
    add_row(ol, "Top K", NULL, win->ollama_top_k);
    win->ollama_repeat_penalty = scale_new(win, 0, 2, 0.05, 2);
    add_row(ol, "Repeat Penalty", NULL, win->ollama_repeat_penalty);
    win->ollama_context = scale_new(win, 512, 8192, 512, 0);
    add_row(ol, "Context Length", NULL, win->ollama_context);
    win->ollama_max_tokens = scale_new(win, 50, 2000, 50, 0);
    add_row(ol, "Max Tokens", NULL, win->ollama_max_tokens);
    GtkWidget *ol_reset = gtk_button_new_with_label("Reset to Defaults");
    gtk_widget_set_halign(ol_reset, GTK_ALIGN_END);
    g_signal_connect(ol_reset, "clicked", G_CALLBACK(on_ollama_reset), win);
    gtk_box_append(GTK_BOX(ol), ol_reset);

    add_section(ol, "Custom System Prompt");
    win->ollama_use_custom = switch_new(win);
    add_row(ol, "Use custom prompt", "Overrides the enhancement mode", win->ollama_use_custom);
    win->ollama_stop = entry_new(win, "e.g. ###, END", 260);
    add_row(ol, "Stop sequences", "Comma-separated", win->ollama_stop);
    win->ollama_custom_prompt = gtk_text_view_new();
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->ollama_custom_prompt), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->ollama_custom_prompt), GTK_WRAP_WORD_CHAR);
    g_signal_connect(gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->ollama_custom_prompt)), "changed",
                     G_CALLBACK(on_signal_changed), win);
    GtkWidget *prompt_frame = gtk_frame_new(NULL);
    gtk_widget_set_size_request(prompt_frame, -1, 120);
    gtk_frame_set_child(GTK_FRAME(prompt_frame), win->ollama_custom_prompt);
    gtk_box_append(GTK_BOX(ol), prompt_frame);
    add_note(ol, "Setup: install Ollama, run `ollama serve`, then `ollama pull llama3.2:3b`.");
    gtk_stack_add_named(GTK_STACK(win->enhancer_stack), ol, "ollama");

    // LM Studio
    GtkWidget *lm = provider_page();
    build_model_picker(win, lm, &win->lm_models, TALKIES_SERVER_LM_STUDIO, "Endpoint", "http://127.0.0.1:1234");
    mode_picker(win, lm, &win->lm_mode, &win->lm_mode_desc);
    add_section(lm, "LLM Parameters");
    win->lm_temperature = scale_new(win, 0, 2, 0.05, 2);
    add_row(lm, "Temperature", NULL, win->lm_temperature);
    win->lm_top_p = scale_new(win, 0, 1, 0.05, 2);
    add_row(lm, "Top P", NULL, win->lm_top_p);
    win->lm_max_tokens = scale_new(win, 50, 8192, 50, 0);
    add_row(lm, "Max Tokens", NULL, win->lm_max_tokens);
    GtkWidget *lm_reset = gtk_button_new_with_label("Reset to Defaults");
    gtk_widget_set_halign(lm_reset, GTK_ALIGN_END);
    g_signal_connect(lm_reset, "clicked", G_CALLBACK(on_lm_reset), win);
    gtk_box_append(GTK_BOX(lm), lm_reset);
    add_note(lm, "Setup: install LM Studio from lmstudio.ai, load a model, and start the local server "
                 "(Developer tab).");
    gtk_stack_add_named(GTK_STACK(win->enhancer_stack), lm, "lm_studio");
}

static gboolean on_close_request(GtkWindow *window, gpointer user_data) {
    TalkiesSettingsWindow *win = user_data;
    // Flush a pending debounced save before hiding.
    if (win->save_source) {
        g_source_remove(win->save_source);
        save_now(win);
    }
    gtk_widget_set_visible(GTK_WIDGET(window), FALSE);
    return TRUE;
}

static void on_open_config_dir(GtkButton *button, gpointer user_data) {
    (void)button;
    const char *path = user_data;
    char *dir = g_path_get_dirname(path);
    char *uri = g_filename_to_uri(dir, NULL, NULL);
    if (uri) g_app_info_launch_default_for_uri(uri, NULL, NULL);
    g_free(uri);
    g_free(dir);
}

TalkiesSettingsWindow *talkies_settings_window_new(const char *const *mode_names,
                                                   const char *const *mode_descriptions,
                                                   const char *config_path) {
    if (!gtk_is_initialized() && !gtk_init_check()) return NULL;

    TalkiesSettingsWindow *win = g_new0(TalkiesSettingsWindow, 1);
    win->mode_names = mode_names;
    win->mode_descriptions = mode_descriptions;
    win->audio_device_names = g_ptr_array_new_with_free_func(g_free);
    win->populating = TRUE;

    win->window = gtk_window_new();
    gtk_window_set_title(GTK_WINDOW(win->window), "Talkies Settings");
    gtk_window_set_default_size(GTK_WINDOW(win->window), 680, 560);
    g_signal_connect(win->window, "close-request", G_CALLBACK(on_close_request), win);

    GtkWidget *paned = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    GtkWidget *stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(stack), GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_widget_set_hexpand(stack, TRUE);
    GtkWidget *sidebar = gtk_stack_sidebar_new();
    gtk_stack_sidebar_set_stack(GTK_STACK_SIDEBAR(sidebar), GTK_STACK(stack));
    gtk_widget_set_size_request(sidebar, 160, -1);
    gtk_box_append(GTK_BOX(paned), sidebar);
    gtk_box_append(GTK_BOX(paned), gtk_separator_new(GTK_ORIENTATION_VERTICAL));
    gtk_box_append(GTK_BOX(paned), stack);
    gtk_window_set_child(GTK_WINDOW(win->window), paned);

    GtkWidget *box;

    // General
    page_new(stack, "general", "General", &box);
    add_section(box, "Hotkey");
    win->threshold = scale_new(win, 0.05, 0.5, 0.05, 2);
    add_row(box, "Push-to-talk threshold (s)",
            "Hold the hotkey longer than this to record while held; a quicker tap toggles recording",
            win->threshold);
    add_note(box, "X11: Right Alt. Wayland: bind talkies-hotkey.sh down/up in your compositor (see README).");
    add_section(box, "Display");
    win->show_hud = switch_new(win);
    add_row(box, "Floating dictation window", "Live waveform and pipeline status while dictating", win->show_hud);
    add_section(box, "Voice Assistant Mode");
    win->voice_assistant = switch_new(win);
    add_row(box, "Enable Voice Assistant", "Speak the result aloud (spd-say / espeak-ng)", win->voice_assistant);
    win->assistant_insert = switch_new(win);
    add_row(box, "Also Insert Text", NULL, win->assistant_insert);

    // Transcription
    page_new(stack, "transcription", "Transcription", &box);
    add_section(box, "Input");
    win->audio_device_list = gtk_string_list_new(NULL);
    win->audio_device = gtk_drop_down_new(G_LIST_MODEL(win->audio_device_list), NULL);
    gtk_widget_set_size_request(win->audio_device, 280, -1);
    g_signal_connect(win->audio_device, "notify::selected", G_CALLBACK(on_changed), win);
    add_row(box, "Microphone", NULL, win->audio_device);
    add_section(box, "Whisper");
    win->model = dropdown_new(win, whisper_models);
    add_row(box, "Model", "Larger models are more accurate but slower", win->model);
    win->language = entry_new(win, "en", 80);
    add_row(box, "Language", "ISO code, e.g. en, de, es", win->language);
    win->vocabulary = entry_new(win, "Talkies, Hyprland, ...", 280);
    add_row(box, "Recognition hints", "Comma-separated names and uncommon words", win->vocabulary);

    // Enhancement
    page_new(stack, "enhancement", "Enhancement", &box);
    build_enhancement_page(win, box);

    // Output
    page_new(stack, "output", "Output", &box);
    add_section(box, "Text Insertion");
    win->auto_paste = switch_new(win);
    add_row(box, "Insert at cursor", "Otherwise the text is only copied to the clipboard", win->auto_paste);
    win->paste_keybind = dropdown_new(win, paste_keybinds);
    add_row(box, "Paste shortcut", "Use ctrl+shift+v for terminals", win->paste_keybind);
    win->restore_clipboard = switch_new(win);
    add_row(box, "Restore clipboard", "Put your previous clipboard back after pasting", win->restore_clipboard);

    // Advanced
    page_new(stack, "advanced", "Advanced", &box);
    add_section(box, "Voice Activity Detection");
    win->vad_enabled = switch_new(win);
    add_row(box, "Trim silence", "Skips silent audio and empty recordings", win->vad_enabled);
    win->vad_mode = dropdown_new(win, vad_modes);
    add_row(box, "Aggressiveness", NULL, win->vad_mode);
    add_section(box, "Diagnostics");
    win->show_status_gui = switch_new(win);
    add_row(box, "Status monitor window", "Live daemon logs (applies on restart)", win->show_status_gui);
    add_section(box, "Configuration");
    GtkWidget *path_label = gtk_label_new(config_path);
    gtk_label_set_selectable(GTK_LABEL(path_label), TRUE);
    gtk_label_set_ellipsize(GTK_LABEL(path_label), PANGO_ELLIPSIZE_MIDDLE);
    gtk_label_set_xalign(GTK_LABEL(path_label), 0);
    gtk_box_append(GTK_BOX(box), path_label);
    GtkWidget *open_dir = gtk_button_new_with_label("Open Config Directory");
    gtk_widget_set_halign(open_dir, GTK_ALIGN_START);
    g_signal_connect_data(open_dir, "clicked", G_CALLBACK(on_open_config_dir), g_strdup(config_path),
                          (GClosureNotify)g_free, 0);
    gtk_box_append(GTK_BOX(box), open_dir);
    add_section(box, "Privacy");
    add_note(box, "All transcription runs on-device. LLM enhancement only talks to servers on this machine.");

    win->populating = FALSE;
    return win;
}

void talkies_settings_window_destroy(TalkiesSettingsWindow *win) {
    if (!win) return;
    if (win->save_source) g_source_remove(win->save_source);
    gtk_window_destroy(GTK_WINDOW(win->window));
    g_ptr_array_unref(win->audio_device_names);
    g_free(win->ollama_models.wanted);
    g_free(win->lm_models.wanted);
    g_free(win);
}

void talkies_settings_window_set_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsSaveFn on_save,
                                           TalkiesSettingsRefreshFn on_refresh, void *user_data) {
    if (!win) return;
    win->on_save = on_save;
    win->on_refresh = on_refresh;
    win->user_data = user_data;
}

static void select_audio_device(TalkiesSettingsWindow *win, const char *name) {
    for (guint i = 0; i < win->audio_device_names->len; i++) {
        if (g_strcmp0(g_ptr_array_index(win->audio_device_names, i), name) == 0) {
            gtk_drop_down_set_selected(GTK_DROP_DOWN(win->audio_device), i);
            return;
        }
    }
    // Unknown (e.g. unplugged) device: keep it selectable rather than losing it.
    gtk_string_list_append(win->audio_device_list, name);
    g_ptr_array_add(win->audio_device_names, g_strdup(name));
    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->audio_device), win->audio_device_names->len - 1);
}

void talkies_settings_window_present(TalkiesSettingsWindow *win, const TalkiesSettingsData *d) {
    if (!win || !d) return;
    win->populating = TRUE;

    gtk_range_set_value(GTK_RANGE(win->threshold), d->push_to_talk_threshold);
    gtk_switch_set_active(GTK_SWITCH(win->show_hud), d->show_hud);
    gtk_switch_set_active(GTK_SWITCH(win->voice_assistant), d->voice_assistant_mode);
    gtk_switch_set_active(GTK_SWITCH(win->assistant_insert), d->insert_text_in_assistant_mode);

    select_audio_device(win, d->audio_device);
    dropdown_select_string(win->model, d->model);
    gtk_editable_set_text(GTK_EDITABLE(win->language), d->language);
    gtk_editable_set_text(GTK_EDITABLE(win->vocabulary), d->vocabulary_prompt);

    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->enhancer), (guint)d->enhancer);
    on_enhancer_changed(NULL, NULL, win);

    gtk_editable_set_text(GTK_EDITABLE(win->ollama_models.url_entry), d->ollama_host);
    g_free(win->ollama_models.wanted);
    win->ollama_models.wanted = g_strdup(d->ollama_model);
    picker_set_models(win, &win->ollama_models, NULL, 0);
    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->ollama_mode), (guint)d->ollama_mode);
    gtk_range_set_value(GTK_RANGE(win->ollama_temperature), d->ollama_temperature);
    gtk_range_set_value(GTK_RANGE(win->ollama_top_p), d->ollama_top_p);
    gtk_range_set_value(GTK_RANGE(win->ollama_top_k), d->ollama_top_k);
    gtk_range_set_value(GTK_RANGE(win->ollama_repeat_penalty), d->ollama_repeat_penalty);
    gtk_range_set_value(GTK_RANGE(win->ollama_context), d->ollama_context_length);
    gtk_range_set_value(GTK_RANGE(win->ollama_max_tokens), d->ollama_max_tokens);
    gtk_switch_set_active(GTK_SWITCH(win->ollama_use_custom), d->ollama_use_custom_prompt);
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->ollama_custom_prompt)),
                             d->ollama_custom_prompt, -1);
    gtk_editable_set_text(GTK_EDITABLE(win->ollama_stop), d->ollama_stop_sequences);

    gtk_editable_set_text(GTK_EDITABLE(win->lm_models.url_entry), d->lm_studio_endpoint);
    g_free(win->lm_models.wanted);
    win->lm_models.wanted = g_strdup(d->lm_studio_model);
    picker_set_models(win, &win->lm_models, NULL, 0);
    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->lm_mode), (guint)d->lm_studio_mode);
    gtk_range_set_value(GTK_RANGE(win->lm_temperature), d->lm_studio_temperature);
    gtk_range_set_value(GTK_RANGE(win->lm_top_p), d->lm_studio_top_p);
    gtk_range_set_value(GTK_RANGE(win->lm_max_tokens), d->lm_studio_max_tokens);
    update_mode_descriptions(win);

    gtk_switch_set_active(GTK_SWITCH(win->auto_paste), d->auto_paste);
    gtk_switch_set_active(GTK_SWITCH(win->restore_clipboard), d->restore_clipboard);
    dropdown_select_string(win->paste_keybind, d->paste_keybind);

    gtk_switch_set_active(GTK_SWITCH(win->vad_enabled), d->vad_enabled);
    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->vad_mode), (guint)d->vad_mode);
    gtk_switch_set_active(GTK_SWITCH(win->show_status_gui), d->show_status_gui);

    win->populating = FALSE;
    gtk_window_present(GTK_WINDOW(win->window));
}

void talkies_settings_window_set_audio_devices(TalkiesSettingsWindow *win, const char *const *names,
                                               const char *const *descriptions, int count) {
    if (!win) return;
    gboolean was_populating = win->populating;
    win->populating = TRUE;
    guint old = g_list_model_get_n_items(G_LIST_MODEL(win->audio_device_list));
    gtk_string_list_splice(win->audio_device_list, 0, old, NULL);
    g_ptr_array_set_size(win->audio_device_names, 0);
    gtk_string_list_append(win->audio_device_list, "System default");
    g_ptr_array_add(win->audio_device_names, g_strdup(""));
    for (int i = 0; i < count; i++) {
        gtk_string_list_append(win->audio_device_list, descriptions && descriptions[i] ? descriptions[i] : names[i]);
        g_ptr_array_add(win->audio_device_names, g_strdup(names[i]));
    }
    win->populating = was_populating;
}

void talkies_settings_window_set_s1_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsActionFn on_download,
                                              TalkiesSettingsActionFn on_remove) {
    if (!win) return;
    win->on_s1_download = on_download;
    win->on_s1_remove = on_remove;
}

void talkies_settings_window_set_s1_state(TalkiesSettingsWindow *win, TalkiesS1State state, double fraction,
                                          const char *detail) {
    if (!win) return;
    char text[256];
    switch (state) {
    case TALKIES_S1_READY: g_snprintf(text, sizeof text, "Installed and ready"); break;
    case TALKIES_S1_DOWNLOADING:
        g_snprintf(text, sizeof text, "Downloading... %d%%", (int)(fraction * 100.0 + 0.5));
        break;
    case TALKIES_S1_FAILED:
        g_snprintf(text, sizeof text, "Download failed%s%s", detail ? ": " : "", detail ? detail : "");
        break;
    case TALKIES_S1_MISSING:
    default: g_snprintf(text, sizeof text, "Not installed"); break;
    }
    gtk_label_set_text(GTK_LABEL(win->s1_status), text);
    gtk_widget_set_visible(win->s1_progress, state == TALKIES_S1_DOWNLOADING);
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(win->s1_progress), fraction);
    gtk_widget_set_visible(win->s1_download, state == TALKIES_S1_MISSING || state == TALKIES_S1_FAILED);
    gtk_button_set_label(GTK_BUTTON(win->s1_download), state == TALKIES_S1_FAILED ? "Retry" : "Download (484 MB)");
    gtk_widget_set_visible(win->s1_remove, state == TALKIES_S1_READY);
}

void talkies_settings_window_set_models(TalkiesSettingsWindow *win, TalkiesServer server,
                                        const char *const *models, int count, const char *status) {
    if (!win) return;
    ModelPicker *picker = server == TALKIES_SERVER_OLLAMA ? &win->ollama_models : &win->lm_models;
    picker_set_models(win, picker, models, count);
    gtk_label_set_text(GTK_LABEL(picker->status), status ? status : "");
}
