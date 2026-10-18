#include "settings_gtk.h"
#include "loop_glib.h"

#include "gtk_compat.h"
#include <string.h>

#define MODE_COUNT 5
#define SAVE_DEBOUNCE_MS 500

static const char *const speech_engines[] = {"Automatic", "Phonon-2", "Whisper", NULL};
static const char *const speech_engine_descriptions[] = {
    "Phonon-2 for English once downloaded, otherwise Whisper",
    "Always prefer Phonon-2 (English-only); Whisper only as fallback",
    "Use Whisper for every language",
    NULL,
};
static const char *const whisper_models[] = {"tiny", "base", "small", "medium", "large", NULL};
static const char *const whisper_model_labels[] = {"Tiny", "Base", "Small", "Medium", "Large", NULL};
static const char *const enhancer_names[] = {"Off", "S1-mini", "Ollama", "LM Studio", NULL};
static const char *const paste_keybinds[] = {"ctrl+v", "ctrl+shift+v", "shift+Insert", NULL};
static const char *const paste_keybind_labels[] = {"Ctrl+V", "Ctrl+Shift+V", "Shift+Insert", NULL};
static const char *const vad_modes[] = {"Quality", "Low bitrate", "Aggressive", "Very aggressive", NULL};
// S1-mini pickers, as in the macOS General settings.
static const char *const cleanup_styles[] = {"Casual", "Semi-Casual", "Semi-Formal", NULL};
static const char *const cleanup_structures[] = {"Prose", "Lists", NULL};
static const char *const cleanup_contexts[] = {"General", "Email", NULL};

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
    GtkWidget *health_icon;
    GtkWidget *health_title;
    GtkWidget *health_fix;
    GtkWidget *health_list;
    GtkWidget *threshold;
    GtkWidget *show_hud;
    GtkWidget *mini_window;
    GtkWidget *launch_at_login;
    GtkWidget *voice_assistant;
    GtkWidget *assistant_insert;
    GtkWidget *assistant_insert_row;
    GtkWidget *save_history;

    // Transcription
    GtkWidget *audio_device;
    GtkStringList *audio_device_list;
    GPtrArray *audio_device_names; // char*, index-aligned with the list
    GtkWidget *speech_engine;
    GtkWidget *phonon_status;
    GtkWidget *phonon_progress;
    GtkWidget *phonon_download;
    GtkWidget *phonon_remove;
    TalkiesSettingsActionFn on_phonon_download;
    TalkiesSettingsActionFn on_phonon_remove;
    GtkWidget *model;
    GtkWidget *language;
    GtkWidget *vocabulary;

    // Enhancement
    GtkWidget *enhancer;
    GtkWidget *enhancer_stack;

    GtkWidget *cleanup_style;
    GtkWidget *cleanup_structure;
    GtkWidget *cleanup_context;
    GtkWidget *s1_status;
    GtkWidget *s1_progress;
    GtkWidget *s1_download;
    GtkWidget *s1_remove;
    TalkiesSettingsActionFn on_s1_download;
    TalkiesSettingsActionFn on_s1_remove;

    ModelPicker ollama_models;
    GtkWidget *ollama_mode;
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

static int choice_get(GtkWidget *widget);
static const char *choice_value(GtkWidget *widget);

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

static char *text_view_text(GtkWidget *view) {
    GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view));
    GtkTextIter start, end;
    gtk_text_buffer_get_bounds(buffer, &start, &end);
    return gtk_text_buffer_get_text(buffer, &start, &end, FALSE);
}

// Vocabulary is edited one term per line (as on macOS) and stored
// comma-separated. Blank lines and stray separators are dropped.
static char *vocabulary_to_config(const char *lines) {
    GString *out = g_string_new(NULL);
    char **terms = g_strsplit_set(lines, "\n,", -1);
    for (char **t = terms; *t; t++) {
        char *term = g_strstrip(*t);
        if (!term[0]) continue;
        if (out->len) g_string_append(out, ", ");
        g_string_append(out, term);
    }
    g_strfreev(terms);
    return g_string_free(out, FALSE);
}

static char *vocabulary_to_lines(const char *config) {
    GString *out = g_string_new(NULL);
    char **terms = g_strsplit(config, ",", -1);
    for (char **t = terms; *t; t++) {
        char *term = g_strstrip(*t);
        if (!term[0]) continue;
        if (out->len) g_string_append_c(out, '\n');
        g_string_append(out, term);
    }
    g_strfreev(terms);
    return g_string_free(out, FALSE);
}

static void collect(TalkiesSettingsWindow *win, TalkiesSettingsData *d) {
    memset(d, 0, sizeof *d);
    d->push_to_talk_threshold = scale_value(win->threshold) / 1000.0;
    d->show_hud = gtk_switch_get_active(GTK_SWITCH(win->show_hud));
    d->mini_window = gtk_switch_get_active(GTK_SWITCH(win->mini_window));
    d->launch_at_login = gtk_switch_get_active(GTK_SWITCH(win->launch_at_login));
    d->voice_assistant_mode = gtk_switch_get_active(GTK_SWITCH(win->voice_assistant));
    d->insert_text_in_assistant_mode = gtk_switch_get_active(GTK_SWITCH(win->assistant_insert));
    d->save_history = gtk_switch_get_active(GTK_SWITCH(win->save_history));

    int device = dropdown_index(win->audio_device);
    const char *device_name = (guint)device < win->audio_device_names->len
                                  ? g_ptr_array_index(win->audio_device_names, device)
                                  : "";
    copy_text(d->audio_device, sizeof d->audio_device, device_name);
    d->speech_engine = choice_get(win->speech_engine);
    copy_text(d->model, sizeof d->model, choice_value(win->model));
    copy_text(d->language, sizeof d->language, gtk_editable_get_text(GTK_EDITABLE(win->language)));
    char *vocabulary_lines = text_view_text(win->vocabulary);
    char *vocabulary = vocabulary_to_config(vocabulary_lines);
    copy_text(d->vocabulary_prompt, sizeof d->vocabulary_prompt, vocabulary);
    g_free(vocabulary);
    g_free(vocabulary_lines);

    d->enhancer = choice_get(win->enhancer);
    d->cleanup_style = choice_get(win->cleanup_style);
    d->cleanup_structure = choice_get(win->cleanup_structure);
    d->cleanup_context = choice_get(win->cleanup_context);

    copy_text(d->ollama_host, sizeof d->ollama_host, gtk_editable_get_text(GTK_EDITABLE(win->ollama_models.url_entry)));
    copy_text(d->ollama_model, sizeof d->ollama_model, dropdown_string(win->ollama_models.dropdown));
    d->ollama_mode = choice_get(win->ollama_mode);
    d->ollama_temperature = scale_value(win->ollama_temperature);
    d->ollama_top_p = scale_value(win->ollama_top_p);
    d->ollama_top_k = (int)scale_value(win->ollama_top_k);
    d->ollama_repeat_penalty = scale_value(win->ollama_repeat_penalty);
    d->ollama_context_length = (int)scale_value(win->ollama_context);
    d->ollama_max_tokens = (int)scale_value(win->ollama_max_tokens);
    d->ollama_use_custom_prompt = gtk_switch_get_active(GTK_SWITCH(win->ollama_use_custom));
    char *prompt = text_view_text(win->ollama_custom_prompt);
    copy_text(d->ollama_custom_prompt, sizeof d->ollama_custom_prompt, prompt);
    g_free(prompt);
    copy_text(d->ollama_stop_sequences, sizeof d->ollama_stop_sequences, gtk_editable_get_text(GTK_EDITABLE(win->ollama_stop)));

    copy_text(d->lm_studio_endpoint, sizeof d->lm_studio_endpoint, gtk_editable_get_text(GTK_EDITABLE(win->lm_models.url_entry)));
    copy_text(d->lm_studio_model, sizeof d->lm_studio_model, dropdown_string(win->lm_models.dropdown));
    d->lm_studio_mode = choice_get(win->lm_mode);
    d->lm_studio_temperature = scale_value(win->lm_temperature);
    d->lm_studio_top_p = scale_value(win->lm_top_p);
    d->lm_studio_max_tokens = (int)scale_value(win->lm_max_tokens);

    d->auto_paste = gtk_switch_get_active(GTK_SWITCH(win->auto_paste));
    d->restore_clipboard = gtk_switch_get_active(GTK_SWITCH(win->restore_clipboard));
    copy_text(d->paste_keybind, sizeof d->paste_keybind, choice_value(win->paste_keybind));

    d->vad_enabled = gtk_switch_get_active(GTK_SWITCH(win->vad_enabled));
    d->vad_mode = choice_get(win->vad_mode);
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

static void on_sidebar_toggled(GtkToggleButton *button, gpointer stack) {
    if (!gtk_toggle_button_get_active(button)) return;
    gtk_stack_set_visible_child_name(GTK_STACK(stack), g_object_get_data(G_OBJECT(button), "page"));
}

/// Sidebar entry: a real button, so screen readers and automation can press
/// it (GtkStackSidebar rows expose no accessible action).
static void sidebar_add(GtkWidget *sidebar, GtkWidget *stack, const char *name, const char *title, const char *icon) {
    GtkWidget *button = gtk_toggle_button_new();
    GtkWidget *content = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_append(GTK_BOX(content), gtk_image_new_from_icon_name(icon));
    GtkWidget *label = gtk_label_new(title);
    gtk_label_set_xalign(GTK_LABEL(label), 0);
    gtk_box_append(GTK_BOX(content), label);
    gtk_button_set_child(GTK_BUTTON(button), content);
    gtk_accessible_update_property(GTK_ACCESSIBLE(button), GTK_ACCESSIBLE_PROPERTY_LABEL, title, -1);
    gtk_widget_add_css_class(button, "flat");
    g_object_set_data_full(G_OBJECT(button), "page", g_strdup(name), g_free);

    GtkWidget *first = gtk_widget_get_first_child(sidebar);
    if (first) {
        gtk_toggle_button_set_group(GTK_TOGGLE_BUTTON(button), GTK_TOGGLE_BUTTON(first));
    } else {
        gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(button), TRUE);
    }
    g_signal_connect(button, "toggled", G_CALLBACK(on_sidebar_toggled), stack);
    gtk_box_append(GTK_BOX(sidebar), button);
}

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

static GtkWidget *add_row(GtkWidget *box, const char *title, const char *subtitle, GtkWidget *control) {
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
    // Name controls after their row so assistive tech and automation can
    // tell the switches apart.
    gtk_accessible_update_relation(GTK_ACCESSIBLE(control), GTK_ACCESSIBLE_RELATION_LABELLED_BY, title_label, NULL, -1);
    if (subtitle) {
        gtk_accessible_update_relation(GTK_ACCESSIBLE(control), GTK_ACCESSIBLE_RELATION_DESCRIBED_BY,
                                       gtk_widget_get_last_child(labels), NULL, -1);
    }
    gtk_widget_set_valign(control, GTK_ALIGN_CENTER);
    gtk_box_append(GTK_BOX(row), labels);
    gtk_box_append(GTK_BOX(row), control);
    gtk_box_append(GTK_BOX(box), row);
    return row;
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

// ---------------------------------------------------------------------------
// Choice control: a segmented button row (short options) or a radio list
// with descriptions (enhancement modes). Unlike GtkDropDown, every option is
// a button with an accessible "click" action and name.
// ---------------------------------------------------------------------------

typedef void (*ChoiceChangedFn)(TalkiesSettingsWindow *win);

typedef struct {
    TalkiesSettingsWindow *win;
    char **values; // owned copy of the stored values, index-aligned with buttons
    ChoiceChangedFn on_changed;
    gboolean radio;
    GPtrArray *buttons; // GtkWidget*, borrowed
} Choice;

static void choice_free(gpointer data) {
    Choice *choice = data;
    g_ptr_array_unref(choice->buttons);
    g_strfreev(choice->values);
    g_free(choice);
}

static Choice *choice_of(GtkWidget *widget) {
    return g_object_get_data(G_OBJECT(widget), "talkies-choice");
}

static gboolean choice_button_active(Choice *choice, GtkWidget *button) {
    return choice->radio ? gtk_check_button_get_active(GTK_CHECK_BUTTON(button))
                         : gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(button));
}

static void on_choice_toggled(GtkWidget *button, gpointer data) {
    Choice *choice = data;
    if (!choice_button_active(choice, button)) return;
    schedule_save(choice->win);
    if (choice->on_changed && !choice->win->populating) choice->on_changed(choice->win);
}

static GtkWidget *choice_new(TalkiesSettingsWindow *win, const char *const *labels, const char *const *values,
                             const char *const *descriptions, ChoiceChangedFn on_changed) {
    Choice *choice = g_new0(Choice, 1);
    choice->win = win;
    choice->values = g_strdupv((char **)(values ? values : labels));
    choice->on_changed = on_changed;
    choice->radio = descriptions != NULL;
    choice->buttons = g_ptr_array_new();

    GtkWidget *box = gtk_box_new(choice->radio ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL,
                                 choice->radio ? 6 : 0);
    if (!choice->radio) gtk_widget_add_css_class(box, "linked");
    g_object_set_data_full(G_OBJECT(box), "talkies-choice", choice, choice_free);

    GtkWidget *first = NULL;
    for (int i = 0; labels[i]; i++) {
        GtkWidget *button;
        if (choice->radio) {
            button = gtk_check_button_new();
            GtkWidget *text = gtk_box_new(GTK_ORIENTATION_VERTICAL, 1);
            GtkWidget *title = gtk_label_new(labels[i]);
            gtk_label_set_xalign(GTK_LABEL(title), 0);
            GtkWidget *desc = gtk_label_new(descriptions[i]);
            gtk_widget_add_css_class(desc, "dim-label");
            gtk_widget_add_css_class(desc, "caption");
            gtk_label_set_xalign(GTK_LABEL(desc), 0);
            gtk_label_set_wrap(GTK_LABEL(desc), TRUE);
            gtk_box_append(GTK_BOX(text), title);
            gtk_box_append(GTK_BOX(text), desc);
            if (talkies_check_button_set_child(GTK_CHECK_BUTTON(button), text)) {
                gtk_accessible_update_relation(GTK_ACCESSIBLE(button), GTK_ACCESSIBLE_RELATION_DESCRIBED_BY, desc, NULL, -1);
            } else {
                // GTK < 4.8: title only, description as tooltip.
                g_object_ref_sink(text);
                g_object_unref(text);
                gtk_check_button_set_label(GTK_CHECK_BUTTON(button), labels[i]);
                gtk_widget_set_tooltip_text(button, descriptions[i]);
            }
            if (first) gtk_check_button_set_group(GTK_CHECK_BUTTON(button), GTK_CHECK_BUTTON(first));
        } else {
            button = gtk_toggle_button_new_with_label(labels[i]);
            if (first) gtk_toggle_button_set_group(GTK_TOGGLE_BUTTON(button), GTK_TOGGLE_BUTTON(first));
        }
        gtk_accessible_update_property(GTK_ACCESSIBLE(button), GTK_ACCESSIBLE_PROPERTY_LABEL, labels[i], -1);
        if (!first) first = button;
        g_signal_connect(button, "toggled", G_CALLBACK(on_choice_toggled), choice);
        g_ptr_array_add(choice->buttons, button);
        gtk_box_append(GTK_BOX(box), button);
    }
    return box;
}

static int choice_get(GtkWidget *widget) {
    Choice *choice = choice_of(widget);
    for (guint i = 0; i < choice->buttons->len; i++) {
        if (choice_button_active(choice, g_ptr_array_index(choice->buttons, i))) return (int)i;
    }
    return 0;
}

static void choice_set(GtkWidget *widget, int index) {
    Choice *choice = choice_of(widget);
    if (index < 0 || (guint)index >= choice->buttons->len) index = 0;
    GtkWidget *button = g_ptr_array_index(choice->buttons, index);
    if (choice->radio) gtk_check_button_set_active(GTK_CHECK_BUTTON(button), TRUE);
    else gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(button), TRUE);
}

static const char *choice_value(GtkWidget *widget) {
    return choice_of(widget)->values[choice_get(widget)];
}

static void choice_set_value(GtkWidget *widget, const char *value) {
    Choice *choice = choice_of(widget);
    for (guint i = 0; i < choice->buttons->len; i++) {
        if (g_strcmp0(choice->values[i], value) == 0) {
            choice_set(widget, (int)i);
            return;
        }
    }
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

static void on_enhancer_changed(TalkiesSettingsWindow *win) {
    static const char *const pages[] = {"none", "s1_mini", "ollama", "lm_studio"};
    int index = choice_get(win->enhancer);
    gtk_stack_set_visible_child_name(GTK_STACK(win->enhancer_stack), pages[index]);
    // Like macOS, check the server as soon as it is chosen.
    if (win->on_refresh && (index == 2 || index == 3)) {
        ModelPicker *picker = index == 2 ? &win->ollama_models : &win->lm_models;
        gtk_label_set_text(GTK_LABEL(picker->status), "Checking...");
        win->on_refresh(index == 2 ? TALKIES_SERVER_OLLAMA : TALKIES_SERVER_LM_STUDIO,
                        gtk_editable_get_text(GTK_EDITABLE(picker->url_entry)), win->user_data);
    }
}

static GtkWidget *mode_picker(TalkiesSettingsWindow *win, GtkWidget *box) {
    const char *names[MODE_COUNT + 1];
    const char *descs[MODE_COUNT + 1];
    for (int i = 0; i < MODE_COUNT; i++) {
        names[i] = win->mode_names[i];
        descs[i] = win->mode_descriptions[i];
    }
    names[MODE_COUNT] = NULL;
    descs[MODE_COUNT] = NULL;
    add_section(box, "Enhancement Mode");
    GtkWidget *picker = choice_new(win, names, NULL, descs, NULL);
    gtk_box_append(GTK_BOX(box), picker);
    return picker;
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

static void on_phonon_download_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    if (win->on_phonon_download) win->on_phonon_download(win->user_data);
}

static void on_phonon_remove_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    TalkiesSettingsWindow *win = user_data;
    if (win->on_phonon_remove) win->on_phonon_remove(win->user_data);
}

static GtkWidget *provider_page(void) {
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    return box;
}

static void build_enhancement_page(TalkiesSettingsWindow *win, GtkWidget *box) {
    add_section(box, "Text Enhancement");
    win->enhancer = choice_new(win, enhancer_names, NULL, NULL, on_enhancer_changed);
    add_row(box, "Enhancer", "Post-process each transcript before it is inserted", win->enhancer);

    win->enhancer_stack = gtk_stack_new();
    gtk_stack_set_vhomogeneous(GTK_STACK(win->enhancer_stack), FALSE);
    gtk_stack_set_hhomogeneous(GTK_STACK(win->enhancer_stack), FALSE);
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
    add_section(s1, "Cleanup Style");
    win->cleanup_style = choice_new(win, cleanup_styles, NULL, NULL, NULL);
    add_row(s1, "Writing style", NULL, win->cleanup_style);
    win->cleanup_structure = choice_new(win, cleanup_structures, NULL, NULL, NULL);
    add_row(s1, "Structure", NULL, win->cleanup_structure);
    win->cleanup_context = choice_new(win, cleanup_contexts, NULL, NULL, NULL);
    add_row(s1, "Context", NULL, win->cleanup_context);
    add_note(s1, "S1-mini by Superwhisper · English · Apache 2.0 with naming clause");
    gtk_stack_add_named(GTK_STACK(win->enhancer_stack), s1, "s1_mini");

    // Ollama
    GtkWidget *ol = provider_page();
    build_model_picker(win, ol, &win->ollama_models, TALKIES_SERVER_OLLAMA, "Host", "http://localhost:11434");
    win->ollama_mode = mode_picker(win, ol);
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
    win->lm_mode = mode_picker(win, lm);
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

// "Push-to-Talk Threshold: 150ms", as on macOS.
static char *format_ms(GtkScale *scale, double value, gpointer user_data) {
    (void)scale;
    (void)user_data;
    return g_strdup_printf("%.0fms", value);
}

// macOS only shows "Also Insert Text" while voice assistant mode is on.
static void on_voice_assistant_changed(GObject *object, GParamSpec *pspec, gpointer user_data) {
    (void)pspec;
    TalkiesSettingsWindow *win = user_data;
    gtk_widget_set_visible(win->assistant_insert_row, gtk_switch_get_active(GTK_SWITCH(object)));
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
    if (!talkies_ui_init()) return NULL;

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
    // Size each page on its own; the widest page must not widen the others.
    gtk_stack_set_hhomogeneous(GTK_STACK(stack), FALSE);
    gtk_widget_set_hexpand(stack, TRUE);
    GtkWidget *sidebar = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    gtk_widget_add_css_class(sidebar, "talkies-sidebar");
    gtk_widget_set_size_request(sidebar, 170, -1);
    GtkCssProvider *css = gtk_css_provider_new();
    gtk_css_provider_load_from_string(css,
        ".talkies-sidebar { padding: 10px 8px; background: alpha(currentColor, 0.04); }"
        ".talkies-sidebar button { border-radius: 8px; padding: 6px 10px; }"
        ".talkies-sidebar button:checked { background: alpha(#3584e4, 0.18); }"
        ".talkies-status { padding: 10px 12px; border-radius: 10px; background: alpha(currentColor, 0.05); }"
        ".talkies-health-ok { color: #26a269; } .talkies-health-warn { color: #c88800; }"
        ".talkies-health-fail { color: #c01c28; }");
    gtk_style_context_add_provider_for_display(gdk_display_get_default(), GTK_STYLE_PROVIDER(css),
                                               GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(css);
    sidebar_add(sidebar, stack, "general", "General", "preferences-system-symbolic");
    sidebar_add(sidebar, stack, "transcription", "Transcription", "audio-input-microphone-symbolic");
    sidebar_add(sidebar, stack, "enhancement", "Enhancement", "starred-symbolic");
    sidebar_add(sidebar, stack, "output", "Output", "edit-paste-symbolic");
    sidebar_add(sidebar, stack, "advanced", "Advanced", "applications-engineering-symbolic");
    gtk_box_append(GTK_BOX(paned), sidebar);
    gtk_box_append(GTK_BOX(paned), gtk_separator_new(GTK_ORIENTATION_VERTICAL));
    gtk_box_append(GTK_BOX(paned), stack);
    gtk_window_set_child(GTK_WINDOW(win->window), paned);

    GtkWidget *box;

    // General
    page_new(stack, "general", "General", &box);
    // Status: one line when everything works; problems (with their fix)
    // only when something needs attention; full detail behind an expander.
    GtkWidget *status_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 10);
    gtk_widget_add_css_class(status_row, "talkies-status");
    win->health_icon = gtk_image_new_from_icon_name("object-select-symbolic");
    gtk_image_set_pixel_size(GTK_IMAGE(win->health_icon), 20);
    gtk_widget_set_valign(win->health_icon, GTK_ALIGN_START);
    GtkWidget *status_text = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
    win->health_title = gtk_label_new("Checking your system...");
    gtk_widget_add_css_class(win->health_title, "heading");
    gtk_label_set_xalign(GTK_LABEL(win->health_title), 0);
    gtk_label_set_wrap(GTK_LABEL(win->health_title), TRUE);
    win->health_fix = gtk_label_new("");
    gtk_widget_add_css_class(win->health_fix, "dim-label");
    gtk_label_set_xalign(GTK_LABEL(win->health_fix), 0);
    gtk_label_set_wrap(GTK_LABEL(win->health_fix), TRUE);
    gtk_label_set_selectable(GTK_LABEL(win->health_fix), TRUE);
    gtk_widget_set_visible(win->health_fix, FALSE);
    gtk_box_append(GTK_BOX(status_text), win->health_title);
    gtk_box_append(GTK_BOX(status_text), win->health_fix);
    gtk_box_append(GTK_BOX(status_row), win->health_icon);
    gtk_box_append(GTK_BOX(status_row), status_text);
    gtk_box_append(GTK_BOX(box), status_row);
    GtkWidget *details = gtk_expander_new("Details");
    win->health_list = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_margin_start(win->health_list, 6);
    gtk_widget_set_margin_top(win->health_list, 4);
    gtk_expander_set_child(GTK_EXPANDER(details), win->health_list);
    gtk_box_append(GTK_BOX(box), details);

    // Section order follows the macOS General settings.
    add_section(box, "Dictation Window");
    win->show_hud = switch_new(win);
    add_row(box, "Show dictation window", "Waveform pill at the top of the screen; opens while you dictate",
            win->show_hud);
    win->mini_window = switch_new(win);
    add_row(box, "Use mini window", "Turn this off to use the larger transcript panel.", win->mini_window);
    add_section(box, "Voice Assistant Mode");
    win->voice_assistant = switch_new(win);
    g_signal_connect(win->voice_assistant, "notify::active", G_CALLBACK(on_voice_assistant_changed), win);
    add_row(box, "Enable Voice Assistant", "Speak the result aloud (spd-say / espeak-ng)", win->voice_assistant);
    win->assistant_insert = switch_new(win);
    win->assistant_insert_row = add_row(box, "Also Insert Text", NULL, win->assistant_insert);
    add_section(box, "Startup");
    win->launch_at_login = switch_new(win);
    add_row(box, "Launch at Login", "Start Talkies when you log in", win->launch_at_login);
    add_section(box, "History");
    win->save_history = switch_new(win);
    add_row(box, "Save transcript history",
            "Keep transcripts on this computer until you delete them (clock button in the dictation window). "
            "Turning this off stops saving; nothing is deleted.",
            win->save_history);
    add_section(box, "Intelligent Detection");
    win->threshold = scale_new(win, 50, 500, 50, 0);
    gtk_scale_set_format_value_func(GTK_SCALE(win->threshold), format_ms, NULL, NULL);
    add_row(box, "Push-to-Talk Threshold",
            "Hold the hotkey longer than this to record while held; a quicker tap toggles recording",
            win->threshold);

    // Transcription
    page_new(stack, "transcription", "Transcription", &box);
    add_section(box, "Input");
    win->audio_device_list = gtk_string_list_new(NULL);
    win->audio_device = gtk_drop_down_new(G_LIST_MODEL(win->audio_device_list), NULL);
    gtk_widget_set_size_request(win->audio_device, 280, -1);
    g_signal_connect(win->audio_device, "notify::selected", G_CALLBACK(on_changed), win);
    add_row(box, "Microphone", NULL, win->audio_device);
    add_section(box, "Speech Engine");
    win->speech_engine = choice_new(win, speech_engines, NULL, speech_engine_descriptions, NULL);
    gtk_box_append(GTK_BOX(box), win->speech_engine);
    add_section(box, "Phonon-2");
    win->phonon_status = gtk_label_new("Checking...");
    gtk_label_set_xalign(GTK_LABEL(win->phonon_status), 0);
    gtk_label_set_wrap(GTK_LABEL(win->phonon_status), TRUE);
    gtk_widget_set_hexpand(win->phonon_status, TRUE);
    win->phonon_download = gtk_button_new_with_label("Download (674 MB)");
    gtk_widget_add_css_class(win->phonon_download, "suggested-action");
    g_signal_connect(win->phonon_download, "clicked", G_CALLBACK(on_phonon_download_clicked), win);
    win->phonon_remove = gtk_button_new_with_label("Remove");
    gtk_widget_add_css_class(win->phonon_remove, "destructive-action");
    g_signal_connect(win->phonon_remove, "clicked", G_CALLBACK(on_phonon_remove_clicked), win);
    GtkWidget *phonon_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_box_append(GTK_BOX(phonon_row), win->phonon_status);
    gtk_box_append(GTK_BOX(phonon_row), win->phonon_download);
    gtk_box_append(GTK_BOX(phonon_row), win->phonon_remove);
    gtk_box_append(GTK_BOX(box), phonon_row);
    win->phonon_progress = gtk_progress_bar_new();
    gtk_widget_set_visible(win->phonon_progress, FALSE);
    gtk_box_append(GTK_BOX(box), win->phonon_progress);
    add_note(box, "English-only, on-device (CrispASR on the CPU). Pinned cstr/phonon2-GGUF (q8_0), "
                  "SHA-256 verified. Phonon-2 by Fermion Research, derived from NVIDIA Parakeet TDT 0.6B v3 · "
                  "CC-BY-4.0. Ignores the personal vocabulary below.");
    add_section(box, "Whisper");
    win->model = choice_new(win, whisper_model_labels, whisper_models, NULL, NULL);
    add_row(box, "Model", "Used for other languages and whenever Phonon-2 is unavailable", win->model);
    win->language = entry_new(win, "en", 80);
    add_row(box, "Language", "ISO code, e.g. en, de, es (Phonon-2 needs en)", win->language);
    add_section(box, "Personal Vocabulary");
    add_note(box, "Names and uncommon words Whisper should recognise, one per line.");
    win->vocabulary = gtk_text_view_new();
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(win->vocabulary), TRUE);
    gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(win->vocabulary), GTK_WRAP_WORD_CHAR);
    gtk_text_view_set_top_margin(GTK_TEXT_VIEW(win->vocabulary), 6);
    gtk_text_view_set_bottom_margin(GTK_TEXT_VIEW(win->vocabulary), 6);
    gtk_text_view_set_left_margin(GTK_TEXT_VIEW(win->vocabulary), 6);
    gtk_accessible_update_property(GTK_ACCESSIBLE(win->vocabulary), GTK_ACCESSIBLE_PROPERTY_LABEL,
                                   "Personal vocabulary", -1);
    g_signal_connect(gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->vocabulary)), "changed",
                     G_CALLBACK(on_signal_changed), win);
    GtkWidget *vocabulary_scroller = gtk_scrolled_window_new();
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(vocabulary_scroller), win->vocabulary);
    gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(vocabulary_scroller), 88);
    gtk_scrolled_window_set_max_content_height(GTK_SCROLLED_WINDOW(vocabulary_scroller), 140);
    gtk_scrolled_window_set_propagate_natural_height(GTK_SCROLLED_WINDOW(vocabulary_scroller), TRUE);
    gtk_widget_add_css_class(vocabulary_scroller, "frame");
    gtk_box_append(GTK_BOX(box), vocabulary_scroller);

    // Enhancement
    page_new(stack, "enhancement", "Enhancement", &box);
    build_enhancement_page(win, box);

    // Output
    page_new(stack, "output", "Output", &box);
    add_section(box, "Text Insertion");
    win->auto_paste = switch_new(win);
    add_row(box, "Insert at cursor", "Otherwise the text is only copied to the clipboard", win->auto_paste);
    win->paste_keybind = choice_new(win, paste_keybind_labels, paste_keybinds, NULL, NULL);
    add_row(box, "Paste shortcut", "Use ctrl+shift+v for terminals", win->paste_keybind);
    win->restore_clipboard = switch_new(win);
    add_row(box, "Restore clipboard", "Put your previous clipboard back after pasting", win->restore_clipboard);

    // Advanced
    page_new(stack, "advanced", "Advanced", &box);
    add_section(box, "Voice Activity Detection");
    win->vad_enabled = switch_new(win);
    add_row(box, "Trim silence", "Skips silent audio and empty recordings", win->vad_enabled);
    win->vad_mode = choice_new(win, vad_modes, NULL, NULL, NULL);
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

// PulseAudio names/descriptions can be 70+ characters; GtkDropDown sizes to
// its widest item, so show a shortened label (the full name is stored).
static char *device_label(const char *text) {
    const glong max_chars = 40;
    if (g_utf8_strlen(text, -1) <= max_chars) return g_strdup(text);
    const char *end = g_utf8_offset_to_pointer(text, max_chars - 1);
    char *head = g_strndup(text, (gsize)(end - text));
    char *label = g_strconcat(head, "…", NULL);
    g_free(head);
    return label;
}

static void select_audio_device(TalkiesSettingsWindow *win, const char *name) {
    // Device listing can fail (no PulseAudio); "System default" always exists.
    if (win->audio_device_names->len == 0) {
        gtk_string_list_append(win->audio_device_list, "System default");
        g_ptr_array_add(win->audio_device_names, g_strdup(""));
    }
    for (guint i = 0; i < win->audio_device_names->len; i++) {
        if (g_strcmp0(g_ptr_array_index(win->audio_device_names, i), name) == 0) {
            gtk_drop_down_set_selected(GTK_DROP_DOWN(win->audio_device), i);
            return;
        }
    }
    // Unknown (e.g. unplugged) device: keep it selectable rather than losing it.
    char *label = device_label(name);
    gtk_string_list_append(win->audio_device_list, label);
    g_free(label);
    g_ptr_array_add(win->audio_device_names, g_strdup(name));
    gtk_drop_down_set_selected(GTK_DROP_DOWN(win->audio_device), win->audio_device_names->len - 1);
}

void talkies_settings_window_present(TalkiesSettingsWindow *win, const TalkiesSettingsData *d) {
    if (!win || !d) return;
    win->populating = TRUE;

    gtk_range_set_value(GTK_RANGE(win->threshold), d->push_to_talk_threshold * 1000.0);
    gtk_switch_set_active(GTK_SWITCH(win->show_hud), d->show_hud);
    gtk_switch_set_active(GTK_SWITCH(win->mini_window), d->mini_window);
    gtk_switch_set_active(GTK_SWITCH(win->launch_at_login), d->launch_at_login);
    gtk_switch_set_active(GTK_SWITCH(win->voice_assistant), d->voice_assistant_mode);
    gtk_switch_set_active(GTK_SWITCH(win->assistant_insert), d->insert_text_in_assistant_mode);
    gtk_widget_set_visible(win->assistant_insert_row, d->voice_assistant_mode);
    gtk_switch_set_active(GTK_SWITCH(win->save_history), d->save_history);

    select_audio_device(win, d->audio_device);
    choice_set(win->speech_engine, d->speech_engine);
    choice_set_value(win->model, d->model);
    gtk_editable_set_text(GTK_EDITABLE(win->language), d->language);
    char *vocabulary = vocabulary_to_lines(d->vocabulary_prompt);
    gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(win->vocabulary)), vocabulary, -1);
    g_free(vocabulary);

    choice_set(win->enhancer, d->enhancer);
    choice_set(win->cleanup_style, d->cleanup_style);
    choice_set(win->cleanup_structure, d->cleanup_structure);
    choice_set(win->cleanup_context, d->cleanup_context);
    on_enhancer_changed(win);

    gtk_editable_set_text(GTK_EDITABLE(win->ollama_models.url_entry), d->ollama_host);
    g_free(win->ollama_models.wanted);
    win->ollama_models.wanted = g_strdup(d->ollama_model);
    picker_set_models(win, &win->ollama_models, NULL, 0);
    choice_set(win->ollama_mode, d->ollama_mode);
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
    choice_set(win->lm_mode, d->lm_studio_mode);
    gtk_range_set_value(GTK_RANGE(win->lm_temperature), d->lm_studio_temperature);
    gtk_range_set_value(GTK_RANGE(win->lm_top_p), d->lm_studio_top_p);
    gtk_range_set_value(GTK_RANGE(win->lm_max_tokens), d->lm_studio_max_tokens);

    gtk_switch_set_active(GTK_SWITCH(win->auto_paste), d->auto_paste);
    gtk_switch_set_active(GTK_SWITCH(win->restore_clipboard), d->restore_clipboard);
    choice_set_value(win->paste_keybind, d->paste_keybind);

    gtk_switch_set_active(GTK_SWITCH(win->vad_enabled), d->vad_enabled);
    choice_set(win->vad_mode, d->vad_mode);
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
        char *label = device_label(descriptions && descriptions[i] ? descriptions[i] : names[i]);
        gtk_string_list_append(win->audio_device_list, label);
        g_free(label);
        g_ptr_array_add(win->audio_device_names, g_strdup(names[i]));
    }
    win->populating = was_populating;
}

static const char *health_icon_name(TalkiesHealthLevel level) {
    switch (level) {
    case TALKIES_HEALTH_FAIL: return "dialog-error-symbolic";
    case TALKIES_HEALTH_WARN: return "dialog-warning-symbolic";
    case TALKIES_HEALTH_OK:
    default: return "object-select-symbolic";
    }
}

static const char *health_css(TalkiesHealthLevel level) {
    switch (level) {
    case TALKIES_HEALTH_FAIL: return "talkies-health-fail";
    case TALKIES_HEALTH_WARN: return "talkies-health-warn";
    case TALKIES_HEALTH_OK:
    default: return "talkies-health-ok";
    }
}

static void set_level_class(GtkWidget *widget, TalkiesHealthLevel level) {
    gtk_widget_remove_css_class(widget, "talkies-health-ok");
    gtk_widget_remove_css_class(widget, "talkies-health-warn");
    gtk_widget_remove_css_class(widget, "talkies-health-fail");
    gtk_widget_add_css_class(widget, health_css(level));
}

void talkies_settings_window_set_health(TalkiesSettingsWindow *win, const TalkiesHealthItem *items, int count) {
    if (!win) return;
    const TalkiesHealthItem *worst = NULL;
    int problems = 0;
    for (int i = 0; i < count; i++) {
        if (items[i].level != TALKIES_HEALTH_OK) problems++;
        if (!worst || items[i].level > worst->level) worst = &items[i];
    }

    TalkiesHealthLevel level = worst ? worst->level : TALKIES_HEALTH_OK;
    gtk_image_set_from_icon_name(GTK_IMAGE(win->health_icon), health_icon_name(level));
    set_level_class(win->health_icon, level);
    if (level == TALKIES_HEALTH_OK) {
        gtk_label_set_text(GTK_LABEL(win->health_title), "Ready to dictate");
        gtk_widget_set_visible(win->health_fix, FALSE);
    } else {
        char title[256];
        if (problems > 1) {
            g_snprintf(title, sizeof title, "%s: %s (+%d more)", worst->title, worst->detail, problems - 1);
        } else {
            g_snprintf(title, sizeof title, "%s: %s", worst->title, worst->detail);
        }
        gtk_label_set_text(GTK_LABEL(win->health_title), title);
        gtk_label_set_text(GTK_LABEL(win->health_fix), worst->fix ? worst->fix : "");
        gtk_widget_set_visible(win->health_fix, worst->fix && worst->fix[0]);
    }

    GtkWidget *child;
    while ((child = gtk_widget_get_first_child(win->health_list))) gtk_box_remove(GTK_BOX(win->health_list), child);
    for (int i = 0; i < count; i++) {
        GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        GtkWidget *icon = gtk_image_new_from_icon_name(health_icon_name(items[i].level));
        set_level_class(icon, items[i].level);
        gtk_widget_set_valign(icon, GTK_ALIGN_START);
        char *text = items[i].level != TALKIES_HEALTH_OK && items[i].fix && items[i].fix[0]
                         ? g_strdup_printf("%s: %s. %s", items[i].title, items[i].detail, items[i].fix)
                         : g_strdup_printf("%s: %s", items[i].title, items[i].detail);
        GtkWidget *label = gtk_label_new(text);
        g_free(text);
        gtk_label_set_xalign(GTK_LABEL(label), 0);
        gtk_label_set_wrap(GTK_LABEL(label), TRUE);
        gtk_label_set_selectable(GTK_LABEL(label), TRUE);
        gtk_box_append(GTK_BOX(row), icon);
        gtk_box_append(GTK_BOX(row), label);
        gtk_box_append(GTK_BOX(win->health_list), row);
    }
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

void talkies_settings_window_set_phonon_callbacks(TalkiesSettingsWindow *win, TalkiesSettingsActionFn on_download,
                                                  TalkiesSettingsActionFn on_remove) {
    if (!win) return;
    win->on_phonon_download = on_download;
    win->on_phonon_remove = on_remove;
}

void talkies_settings_window_set_phonon_state(TalkiesSettingsWindow *win, TalkiesS1State state, double fraction,
                                              const char *detail) {
    if (!win) return;
    char text[320];
    switch (state) {
    case TALKIES_S1_READY:
        if (detail && detail[0]) g_snprintf(text, sizeof text, "Installed, but could not load: %s", detail);
        else g_snprintf(text, sizeof text, "Installed and ready");
        break;
    case TALKIES_S1_DOWNLOADING:
        g_snprintf(text, sizeof text, "Downloading... %d%%", (int)(fraction * 100.0 + 0.5));
        break;
    case TALKIES_S1_FAILED:
        g_snprintf(text, sizeof text, "Download failed%s%s", detail ? ": " : "", detail ? detail : "");
        break;
    case TALKIES_S1_MISSING:
    default: g_snprintf(text, sizeof text, "Not installed: Whisper transcribes until you download it"); break;
    }
    gtk_label_set_text(GTK_LABEL(win->phonon_status), text);
    gtk_widget_set_visible(win->phonon_progress, state == TALKIES_S1_DOWNLOADING);
    gtk_progress_bar_set_fraction(GTK_PROGRESS_BAR(win->phonon_progress), fraction);
    gtk_widget_set_visible(win->phonon_download, state == TALKIES_S1_MISSING || state == TALKIES_S1_FAILED);
    gtk_button_set_label(GTK_BUTTON(win->phonon_download), state == TALKIES_S1_FAILED ? "Retry" : "Download (674 MB)");
    gtk_widget_set_visible(win->phonon_remove, state == TALKIES_S1_READY);
}

void talkies_settings_window_set_models(TalkiesSettingsWindow *win, TalkiesServer server,
                                        const char *const *models, int count, const char *status) {
    if (!win) return;
    ModelPicker *picker = server == TALKIES_SERVER_OLLAMA ? &win->ollama_models : &win->lm_models;
    picker_set_models(win, picker, models, count);
    gtk_label_set_text(GTK_LABEL(picker->status), status ? status : "");
}
