#include <jni.h>
#include <llama.h>

#include <algorithm>
#include <exception>
#include <mutex>
#include <string>
#include <unistd.h>
#include <vector>

namespace {

constexpr size_t kMaximumPromptBytes = 8 * 1024;
constexpr uint32_t kContextLength = 3072;
constexpr int32_t kMaximumOutputTokens = 512;

std::mutex inference_mutex;
std::once_flag backend_once;

struct Runtime {
    llama_model *model = nullptr;
    llama_context *context = nullptr;
    const llama_vocab *vocabulary = nullptr;
    std::string model_path;

    void unload() {
        if (context != nullptr) llama_free(context);
        if (model != nullptr) llama_model_free(model);
        context = nullptr;
        model = nullptr;
        vocabulary = nullptr;
        model_path.clear();
    }

    ~Runtime() { unload(); }
};

Runtime runtime;

struct BatchOwner {
    llama_batch value;
    explicit BatchOwner(int32_t token_count) : value(llama_batch_init(token_count, 0, 1)) {}
    ~BatchOwner() { llama_batch_free(value); }
};

struct SamplerOwner {
    llama_sampler *value;
    ~SamplerOwner() {
        if (value != nullptr) llama_sampler_free(value);
    }
};

void throwJavaException(JNIEnv *env, const char *message) {
    jclass exception = env->FindClass("java/lang/IllegalStateException");
    if (exception != nullptr) {
        env->ThrowNew(exception, message);
        env->DeleteLocalRef(exception);
    }
}

bool ensureRuntime(const std::string &model_path) {
    std::call_once(backend_once, [] { llama_backend_init(); });
    if (runtime.model != nullptr && runtime.model_path == model_path) return true;
    runtime.unload();

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0;
    runtime.model = llama_model_load_from_file(model_path.c_str(), model_params);
    if (runtime.model == nullptr) return false;

    llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = kContextLength;
    context_params.n_batch = 2048;
    context_params.n_ubatch = 512;
    context_params.n_threads = std::max(2, std::min(4, static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN))));
    context_params.n_threads_batch = context_params.n_threads;
    runtime.context = llama_init_from_model(runtime.model, context_params);
    if (runtime.context == nullptr) {
        runtime.unload();
        return false;
    }
    runtime.vocabulary = llama_model_get_vocab(runtime.model);
    if (runtime.vocabulary == nullptr) {
        runtime.unload();
        return false;
    }
    runtime.model_path = model_path;
    return true;
}

std::string copyJavaUtf8(JNIEnv *env, jbyteArray input) {
    const jsize length = env->GetArrayLength(input);
    std::string value(static_cast<size_t>(length), '\0');
    if (length > 0) {
        env->GetByteArrayRegion(input, 0, length, reinterpret_cast<jbyte *>(value.data()));
    }
    return value;
}

}  // namespace

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_talkies_android_LocalWhisper_clean(
    JNIEnv *env,
    jobject /* receiver */,
    jstring model_path_value,
    jbyteArray prompt_value
) {
    if (model_path_value == nullptr || prompt_value == nullptr) {
        throwJavaException(env, "A verified S1-mini model and cleanup prompt are required.");
        return nullptr;
    }

    const char *model_path_chars = env->GetStringUTFChars(model_path_value, nullptr);
    if (model_path_chars == nullptr) return nullptr;
    const std::string model_path(model_path_chars);
    env->ReleaseStringUTFChars(model_path_value, model_path_chars);
    const std::string prompt = copyJavaUtf8(env, prompt_value);
    if (env->ExceptionCheck()) return nullptr;
    if (prompt.empty() || prompt.size() > kMaximumPromptBytes) {
        throwJavaException(env, "The transcript is empty or too long for local S1-mini cleanup.");
        return nullptr;
    }

    try {
        std::lock_guard<std::mutex> lock(inference_mutex);
        if (!ensureRuntime(model_path)) {
            throwJavaException(env, "S1-mini could not load its local CPU model.");
            return nullptr;
        }

        llama_memory_clear(llama_get_memory(runtime.context), true);
        const int32_t token_capacity = static_cast<int32_t>(prompt.size() + 16);
        std::vector<llama_token> prompt_tokens(static_cast<size_t>(token_capacity));
        const int32_t prompt_token_count = llama_tokenize(
            runtime.vocabulary,
            prompt.c_str(),
            static_cast<int32_t>(prompt.size()),
            prompt_tokens.data(),
            token_capacity,
            false,
            true
        );
        if (prompt_token_count <= 0 || prompt_token_count >= 2048) {
            throwJavaException(env, "S1-mini could not tokenize the local cleanup prompt.");
            return nullptr;
        }

        BatchOwner batch_owner(prompt_token_count);
        llama_batch &batch = batch_owner.value;
        if (batch.token == nullptr || batch.pos == nullptr || batch.n_seq_id == nullptr ||
            batch.seq_id == nullptr || batch.logits == nullptr) {
            throwJavaException(env, "S1-mini could not allocate its CPU inference batch.");
            return nullptr;
        }
        batch.n_tokens = prompt_token_count;
        for (int32_t index = 0; index < prompt_token_count; ++index) {
            batch.token[index] = prompt_tokens[static_cast<size_t>(index)];
            batch.pos[index] = index;
            batch.n_seq_id[index] = 1;
            batch.seq_id[index][0] = 0;
            batch.logits[index] = index == prompt_token_count - 1;
        }
        if (llama_decode(runtime.context, batch) != 0) {
            throwJavaException(env, "S1-mini could not evaluate the cleanup prompt.");
            return nullptr;
        }

        SamplerOwner sampler_owner{llama_sampler_chain_init(llama_sampler_chain_default_params())};
        llama_sampler *sampler = sampler_owner.value;
        if (sampler == nullptr) {
            throwJavaException(env, "S1-mini could not initialize deterministic decoding.");
            return nullptr;
        }
        llama_sampler *greedy_sampler = llama_sampler_init_greedy();
        if (greedy_sampler == nullptr) {
            throwJavaException(env, "S1-mini could not initialize deterministic decoding.");
            return nullptr;
        }
        llama_sampler_chain_add(sampler, greedy_sampler);

        const int32_t output_limit = std::min(
            kMaximumOutputTokens,
            static_cast<int32_t>(kContextLength) - prompt_token_count - 1
        );
        std::string output;
        int32_t current_position = prompt_token_count;
        for (int32_t index = 0; index < output_limit; ++index) {
            const llama_token token = llama_sampler_sample(sampler, runtime.context, batch.n_tokens - 1);
            if (token < 0) {
                throwJavaException(env, "S1-mini could not generate the local cleanup result.");
                return nullptr;
            }
            if (llama_vocab_is_eog(runtime.vocabulary, token)) break;
            llama_sampler_accept(sampler, token);

            std::vector<char> token_piece(128);
            int32_t byte_count = llama_token_to_piece(
                runtime.vocabulary,
                token,
                token_piece.data(),
                static_cast<int32_t>(token_piece.size()),
                0,
                false
            );
            if (byte_count < 0) {
                token_piece.resize(static_cast<size_t>(-byte_count));
                byte_count = llama_token_to_piece(
                    runtime.vocabulary,
                    token,
                    token_piece.data(),
                    static_cast<int32_t>(token_piece.size()),
                    0,
                    false
                );
            }
            if (byte_count > 0) output.append(token_piece.data(), static_cast<size_t>(byte_count));

            batch.n_tokens = 1;
            batch.token[0] = token;
            batch.pos[0] = current_position++;
            batch.n_seq_id[0] = 1;
            batch.seq_id[0][0] = 0;
            batch.logits[0] = true;
            if (llama_decode(runtime.context, batch) != 0) {
                throwJavaException(env, "S1-mini stopped while cleaning the local transcript.");
                return nullptr;
            }
        }

        if (output.size() > 32 * 1024) output.resize(32 * 1024);
        jbyteArray result = env->NewByteArray(static_cast<jsize>(output.size()));
        if (result != nullptr && !output.empty()) {
            env->SetByteArrayRegion(
                result,
                0,
                static_cast<jsize>(output.size()),
                reinterpret_cast<const jbyte *>(output.data())
            );
        }
        return result;
    } catch (const std::exception &error) {
        throwJavaException(env, error.what());
        return nullptr;
    } catch (...) {
        throwJavaException(env, "S1-mini encountered an unexpected local inference error.");
        return nullptr;
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_talkies_android_LocalWhisper_unloadCleanupModel(JNIEnv *, jobject) {
    std::lock_guard<std::mutex> lock(inference_mutex);
    runtime.unload();
}
