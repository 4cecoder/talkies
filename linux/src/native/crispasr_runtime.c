// CrispASR session adapter for Phonon-2. See crispasr_runtime.h.
//
// libcrispasr is a whisper.cpp descendant: it exports whisper_* symbols and
// depends on its own libggml*.so.0, which share sonames (but not the ABI)
// with the ggml Talkies bundles for whisper.cpp and llama.cpp. Loading it
// with dlopen would bind it to the wrong ggml. dlmopen(LM_ID_NEWLM) gives it
// a separate link-map namespace instead, and preloading each bundled library
// by absolute path keeps LD_LIBRARY_PATH from substituting a system copy.
// The namespace is never unloaded: CrispASR's OpenMP threads outlive a call.

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "crispasr_runtime.h"

// The generated upstream header is written for C++: it names
// `whisper_full_params` without a C typedef. Supply the identical typedef
// (C11 permits the redeclaration) instead of editing the vendored header.
typedef struct whisper_full_params whisper_full_params;
#include <crispasr_session.h> // vendored, pinned CrispASR v0.8.43

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__linux__) && defined(__GLIBC__)
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#define TALKIES_HAVE_DLMOPEN 1
#endif

// Function types come from the pinned header, so an ABI change fails to compile.
typedef __typeof__(&crispasr_session_open_explicit) open_explicit_fn;
typedef __typeof__(&crispasr_session_close) close_fn;
typedef __typeof__(&crispasr_session_transcribe_lang) transcribe_lang_fn;
typedef __typeof__(&crispasr_session_transcribe_chunked_lang) transcribe_chunked_lang_fn;
typedef __typeof__(&crispasr_session_result_n_segments) n_segments_fn;
typedef __typeof__(&crispasr_session_result_segment_text) segment_text_fn;
typedef __typeof__(&crispasr_session_result_free) result_free_fn;

typedef struct {
    open_explicit_fn open_explicit;
    close_fn close;
    transcribe_lang_fn transcribe_lang;
    transcribe_chunked_lang_fn transcribe_chunked_lang;
    n_segments_fn n_segments;
    segment_text_fn segment_text;
    result_free_fn result_free;
} crispasr_api;

struct talkies_crispasr {
    crispasr_session *session;
};

// Phonon-2 runs on CrispASR's Parakeet TDT backend.
static const char backend_name[] = "parakeet";
// Above this, use CrispASR's bounded long-form path (the decoder's reliable
// single-pass window is about 30 s).
static const int32_t single_pass_samples = 30 * 16000;

static void set_error(char *error, size_t capacity, const char *fmt, ...) {
    if (!error || capacity == 0) return;
    va_list args;
    va_start(args, fmt);
    vsnprintf(error, capacity, fmt, args);
    va_end(args);
}

#ifdef TALKIES_HAVE_DLMOPEN

// Load order: each library's dependencies come first, so its NEEDED entries
// resolve to the copy already loaded in the namespace. Optional entries may
// be absent (libquadmath is x86_64-only).
static const struct {
    const char *name;
    int required;
} bundle[] = {
    {"libquadmath.so.0", 0}, {"libgfortran.so.5", 0}, {"libgomp.so.1", 0},     {"libopenblas.so.0", 0},
    {"libggml-base.so.0", 1}, {"libggml-cpu.so.0", 1}, {"libggml.so.0", 1}, {"libcrispasr.so.1", 1},
};

static pthread_mutex_t api_lock = PTHREAD_MUTEX_INITIALIZER;
static crispasr_api api;
static int api_loaded;

static int load_api(const char *runtime_dir, char *error, size_t capacity) {
    Lmid_t namespace_id = LM_ID_NEWLM;
    void *crispasr = NULL;
    for (size_t i = 0; i < sizeof bundle / sizeof bundle[0]; i++) {
        char path[4096];
        int n = snprintf(path, sizeof path, "%s/%s", runtime_dir, bundle[i].name);
        if (n < 0 || (size_t)n >= sizeof path) {
            set_error(error, capacity, "CrispASR runtime path is too long");
            return 0;
        }
        if (access(path, R_OK) != 0) {
            if (!bundle[i].required) continue;
            set_error(error, capacity, "CrispASR runtime is not installed (%s missing)", path);
            return 0;
        }
        void *handle = dlmopen(namespace_id, path, RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            const char *reason = dlerror();
            set_error(error, capacity, "could not load %s: %s", bundle[i].name, reason ? reason : "unknown error");
            return 0;
        }
        if (namespace_id == LM_ID_NEWLM && dlinfo(handle, RTLD_DI_LMID, &namespace_id) != 0) {
            set_error(error, capacity, "could not query the CrispASR namespace");
            return 0;
        }
        crispasr = handle;
    }

#define TALKIES_RESOLVE(field, symbol)                                                                                 \
    do {                                                                                                               \
        *(void **)(&api.field) = dlsym(crispasr, #symbol);                                                             \
        if (!api.field) {                                                                                              \
            set_error(error, capacity, "CrispASR runtime lacks %s", #symbol);                                          \
            return 0;                                                                                                  \
        }                                                                                                              \
    } while (0)
    TALKIES_RESOLVE(open_explicit, crispasr_session_open_explicit);
    TALKIES_RESOLVE(close, crispasr_session_close);
    TALKIES_RESOLVE(transcribe_lang, crispasr_session_transcribe_lang);
    TALKIES_RESOLVE(transcribe_chunked_lang, crispasr_session_transcribe_chunked_lang);
    TALKIES_RESOLVE(n_segments, crispasr_session_result_n_segments);
    TALKIES_RESOLVE(segment_text, crispasr_session_result_segment_text);
    TALKIES_RESOLVE(result_free, crispasr_session_result_free);
#undef TALKIES_RESOLVE
    return 1;
}

static const crispasr_api *acquire_api(const char *runtime_dir, char *error, size_t capacity) {
    pthread_mutex_lock(&api_lock);
    // A failed attempt leaves partial handles in an orphaned namespace; a
    // retry starts a new one. Talkies retries only after the user acts.
    if (!api_loaded) api_loaded = load_api(runtime_dir, error, capacity);
    const crispasr_api *result = api_loaded ? &api : NULL;
    pthread_mutex_unlock(&api_lock);
    return result;
}

#else

static const crispasr_api *acquire_api(const char *runtime_dir, char *error, size_t capacity) {
    (void)runtime_dir;
    set_error(error, capacity, "CrispASR needs glibc's dlmopen; this build cannot load it");
    return NULL;
}

#endif

talkies_crispasr *talkies_crispasr_open(const char *runtime_dir, const char *model_path, int32_t threads, char *error,
                                        size_t error_capacity) {
    if (!runtime_dir || !model_path) {
        set_error(error, error_capacity, "missing CrispASR runtime or model path");
        return NULL;
    }
    const crispasr_api *a = acquire_api(runtime_dir, error, error_capacity);
    if (!a) return NULL;

    talkies_crispasr *runtime = calloc(1, sizeof *runtime);
    if (!runtime) {
        set_error(error, error_capacity, "out of memory");
        return NULL;
    }
    runtime->session = a->open_explicit(model_path, backend_name, threads > 0 ? threads : 1);
    if (!runtime->session) {
        set_error(error, error_capacity, "CrispASR could not open the model with its %s backend", backend_name);
        free(runtime);
        return NULL;
    }
    return runtime;
}

static int is_space(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

char *talkies_crispasr_transcribe(talkies_crispasr *runtime, const float *pcm, int32_t n_samples, const char *language,
                                  char *error, size_t error_capacity) {
    if (!runtime || !runtime->session) {
        set_error(error, error_capacity, "Phonon-2 is not loaded");
        return NULL;
    }
    if (!pcm || n_samples <= 0) return strdup("");
    const crispasr_api *a = acquire_api("", error, error_capacity);
    if (!a) return NULL;

    const char *lang = language && language[0] ? language : "en";
    crispasr_session_result *result =
        n_samples > single_pass_samples
            ? a->transcribe_chunked_lang(runtime->session, pcm, n_samples, 0, -1, lang)
            : a->transcribe_lang(runtime->session, pcm, n_samples, lang);
    if (!result) {
        set_error(error, error_capacity, "Phonon-2 transcription failed");
        return NULL;
    }

    // Join trimmed segment texts with single spaces.
    int count = a->n_segments(result);
    size_t total = 1;
    for (int i = 0; i < count; i++) {
        const char *text = a->segment_text(result, i);
        if (text) total += strlen(text) + 1;
    }
    char *out = malloc(total);
    if (!out) {
        a->result_free(result);
        set_error(error, error_capacity, "out of memory");
        return NULL;
    }
    size_t len = 0;
    for (int i = 0; i < count; i++) {
        const char *text = a->segment_text(result, i);
        if (!text) continue;
        size_t start = 0, end = strlen(text);
        while (start < end && is_space(text[start])) start++;
        while (end > start && is_space(text[end - 1])) end--;
        if (end == start) continue;
        if (len > 0) out[len++] = ' ';
        memcpy(out + len, text + start, end - start);
        len += end - start;
    }
    out[len] = '\0';
    a->result_free(result);
    return out;
}

void talkies_crispasr_free_text(char *text) {
    free(text);
}

void talkies_crispasr_close(talkies_crispasr *runtime) {
    if (!runtime) return;
    if (runtime->session) {
        char ignored[8];
        const crispasr_api *a = acquire_api("", ignored, sizeof ignored);
        if (a) a->close(runtime->session);
    }
    free(runtime);
}
