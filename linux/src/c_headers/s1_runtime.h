#ifndef TALKIES_S1_RUNTIME_H
#define TALKIES_S1_RUNTIME_H

#include <stddef.h>
#include <stdint.h>

typedef struct talkies_s1_runtime talkies_s1_runtime;

talkies_s1_runtime *talkies_s1_runtime_create(const char *model_path, int32_t threads);
int talkies_s1_runtime_clean(talkies_s1_runtime *runtime, const char *prompt, char *output, size_t output_capacity);
void talkies_s1_runtime_destroy(talkies_s1_runtime *runtime);

#endif
