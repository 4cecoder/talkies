#include "c_headers/s1_runtime.h"

#include <llama.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TALKIES_S1_CONTEXT 3072
#define TALKIES_S1_MAX_OUTPUT_TOKENS 768
#define TALKIES_S1_TOKEN_PIECE_CAPACITY 4096

struct talkies_s1_runtime {
    struct llama_model *model;
    struct llama_context *context;
    const struct llama_vocab *vocabulary;
    struct llama_sampler *sampler;
};

static void talkies_s1_log(enum ggml_log_level level, const char *text, void *user_data) {
    (void)user_data;
    if ((level == GGML_LOG_LEVEL_WARN || level == GGML_LOG_LEVEL_ERROR) && text != NULL) {
        fputs(text, stderr);
    }
}

talkies_s1_runtime *talkies_s1_runtime_create(const char *model_path, int32_t threads) {
    if (model_path == NULL) return NULL;
    if (threads < 1) threads = 1;
    if (threads > 16) threads = 16;

    llama_log_set(talkies_s1_log, NULL);
    llama_backend_init();
    struct llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    struct llama_model *model = llama_model_load_from_file(model_path, model_params);
    if (model == NULL) return NULL;

    struct llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = TALKIES_S1_CONTEXT;
    context_params.n_batch = 2048;
    context_params.n_ubatch = 512;
    context_params.n_threads = threads;
    context_params.n_threads_batch = threads;
    struct llama_context *context = llama_init_from_model(model, context_params);
    if (context == NULL) {
        llama_model_free(model);
        return NULL;
    }

    struct llama_sampler_chain_params sampler_params = llama_sampler_chain_default_params();
    struct llama_sampler *sampler = llama_sampler_chain_init(sampler_params);
    if (sampler == NULL) {
        llama_free(context);
        llama_model_free(model);
        return NULL;
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_greedy());

    talkies_s1_runtime *runtime = calloc(1, sizeof(*runtime));
    if (runtime == NULL) {
        llama_sampler_free(sampler);
        llama_free(context);
        llama_model_free(model);
        return NULL;
    }
    runtime->model = model;
    runtime->context = context;
    runtime->vocabulary = llama_model_get_vocab(model);
    runtime->sampler = sampler;
    return runtime;
}

int talkies_s1_runtime_clean(talkies_s1_runtime *runtime, const char *prompt, char *output, size_t output_capacity) {
    if (runtime == NULL || prompt == NULL || output == NULL || output_capacity == 0) return -1;
    output[0] = '\0';

    llama_memory_clear(llama_get_memory(runtime->context), true);
    llama_sampler_reset(runtime->sampler);

    const size_t prompt_length = strlen(prompt);
    if (prompt_length > INT32_MAX - 16) return -2;
    const int32_t token_capacity = (int32_t)prompt_length + 16;
    llama_token *tokens = malloc((size_t)token_capacity * sizeof(*tokens));
    if (tokens == NULL) return -3;
    const int32_t token_count = llama_tokenize(runtime->vocabulary, prompt, (int32_t)prompt_length,
                                               tokens, token_capacity, false, true);
    if (token_count < 0 || token_count > TALKIES_S1_CONTEXT) {
        free(tokens);
        return -4;
    }

    struct llama_batch prompt_batch = llama_batch_get_one(tokens, token_count);
    if (llama_decode(runtime->context, prompt_batch) != 0) {
        free(tokens);
        return -5;
    }

    size_t output_length = 0;
    int result = 0;
    int32_t generated = 0;
    for (; generated < TALKIES_S1_MAX_OUTPUT_TOKENS; generated++) {
        const llama_token token = llama_sampler_sample(runtime->sampler, runtime->context, -1);
        if (llama_vocab_is_eog(runtime->vocabulary, token)) break;

        char piece[TALKIES_S1_TOKEN_PIECE_CAPACITY];
        const int32_t piece_length = llama_token_to_piece(runtime->vocabulary, token, piece,
                                                           sizeof(piece), 0, false);
        if (piece_length < 0 || (size_t)piece_length > output_capacity - output_length - 1) {
            result = -6;
            break;
        }
        memcpy(output + output_length, piece, (size_t)piece_length);
        output_length += (size_t)piece_length;
        output[output_length] = '\0';

        struct llama_batch next = llama_batch_get_one((llama_token *)&token, 1);
        if (llama_decode(runtime->context, next) != 0) {
            result = -7;
            break;
        }
    }
    if (result == 0 && generated == TALKIES_S1_MAX_OUTPUT_TOKENS) result = -8;
    free(tokens);
    return result;
}

void talkies_s1_runtime_destroy(talkies_s1_runtime *runtime) {
    if (runtime == NULL) return;
    llama_sampler_free(runtime->sampler);
    llama_free(runtime->context);
    llama_model_free(runtime->model);
    free(runtime);
}
