#ifndef TALKIES_CRISPASR_RUNTIME_H
#define TALKIES_CRISPASR_RUNTIME_H

// Talkies-owned C ABI over CrispASR's session API (Phonon-2 via the Parakeet
// TDT backend). The CrispASR libraries are loaded from `runtime_dir` into a
// private dlmopen namespace on first use; they are never linked into Talkies.
// Every call that can fail writes a NUL-terminated reason into `error`.

#include <stddef.h>
#include <stdint.h>

typedef struct talkies_crispasr talkies_crispasr;

// Load the runtime (once per process) and open `model_path`. NULL on failure.
talkies_crispasr *talkies_crispasr_open(const char *runtime_dir, const char *model_path, int32_t threads, char *error,
                                        size_t error_capacity);

// Transcribe 16 kHz mono float PCM. Returns a malloc'd UTF-8 string (free it
// with talkies_crispasr_free_text), or NULL on failure.
char *talkies_crispasr_transcribe(talkies_crispasr *runtime, const float *pcm, int32_t n_samples, const char *language,
                                  char *error, size_t error_capacity);

void talkies_crispasr_free_text(char *text);
void talkies_crispasr_close(talkies_crispasr *runtime);

#endif
