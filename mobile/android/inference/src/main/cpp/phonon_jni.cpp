// JNI adapter for Phonon-2 through CrispASR's Parakeet TDT backend.
//
// Built into libtalkies_phonon.so, separate from libtalkies_whisper.so: CrispASR carries its own
// ggml fork and whisper_* symbols, so every symbol except the JNI entry points stays hidden
// (see phonon_exports.map).

#include <jni.h>

#include <exception>
#include <mutex>
#include <new>
#include <string>
#include <vector>

#include "parakeet.h"
#include "parakeet_orchestrate.h"

namespace {

std::mutex runtime_mutex;
parakeet_context *context = nullptr;
std::string loaded_model_path;

void throwJavaException(JNIEnv *env, const char *message) {
    if (env->ExceptionCheck()) return;
    jclass exception = env->FindClass("java/lang/IllegalStateException");
    if (exception != nullptr) {
        env->ThrowNew(exception, message);
        env->DeleteLocalRef(exception);
    }
}

void unloadLocked() {
    if (context != nullptr) parakeet_free(context);
    context = nullptr;
    loaded_model_path.clear();
}

template <typename T>
void wipe(std::vector<T> &values) {
    volatile T *data = values.data();
    for (size_t index = 0; index < values.size(); ++index) data[index] = T{};
    values.clear();
    values.shrink_to_fit();
}

void wipe(std::string &value) {
    volatile char *data = value.data();
    for (size_t index = 0; index < value.size(); ++index) data[index] = 0;
    value.clear();
    value.shrink_to_fit();
}

std::string trim(const std::string &value) {
    const size_t first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return {};
    const size_t last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

}  // namespace

extern "C" JNIEXPORT jboolean JNICALL
Java_com_talkies_android_LocalPhonon_nativeLoad(JNIEnv *env, jobject /* receiver */, jstring model_path, jint threads) {
    if (model_path == nullptr) {
        throwJavaException(env, "A verified Phonon-2 model is required.");
        return JNI_FALSE;
    }
    const char *path_chars = env->GetStringUTFChars(model_path, nullptr);
    if (path_chars == nullptr) return JNI_FALSE;
    const std::string path(path_chars);
    env->ReleaseStringUTFChars(model_path, path_chars);

    std::lock_guard<std::mutex> lock(runtime_mutex);
    if (context != nullptr && loaded_model_path == path) return JNI_TRUE;
    unloadLocked();

    try {
        parakeet_context_params params = parakeet_context_default_params();
        params.n_threads = threads > 0 ? threads : 2;
        params.use_gpu = false;
        params.verbosity = 0;
        parakeet_context *candidate = parakeet_init_from_file(path.c_str(), params);
        if (candidate == nullptr) return JNI_FALSE;
        // Phonon-2 is English-only. Refuse anything else rather than silently running another model.
        if (!parakeet_is_english_only(candidate) || parakeet_vocab_is_japanese(candidate) != 0) {
            parakeet_free(candidate);
            return JNI_FALSE;
        }
        context = candidate;
        loaded_model_path = path;
        return JNI_TRUE;
    } catch (const std::bad_alloc &) {
        unloadLocked();
        return JNI_FALSE;
    } catch (const std::exception &) {
        unloadLocked();
        return JNI_FALSE;
    }
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_talkies_android_LocalPhonon_nativeTranscribe(JNIEnv *env, jobject /* receiver */, jfloatArray audio_samples) {
    if (audio_samples == nullptr) {
        throwJavaException(env, "No audio samples were recorded.");
        return nullptr;
    }
    const jsize sample_count = env->GetArrayLength(audio_samples);
    if (sample_count <= 0) {
        throwJavaException(env, "No audio samples were recorded.");
        return nullptr;
    }

    std::lock_guard<std::mutex> lock(runtime_mutex);
    if (context == nullptr) {
        throwJavaException(env, "Phonon-2 is not loaded.");
        return nullptr;
    }

    std::vector<float> samples;
    std::string transcript;
    std::vector<parakeet_seg> segments;
    try {
        // Copy into memory this adapter owns so it can be wiped; GetFloatArrayElements may hand back
        // a VM copy that JNI_ABORT would release without clearing.
        samples.resize(static_cast<size_t>(sample_count));
        env->GetFloatArrayRegion(audio_samples, 0, sample_count, samples.data());
        if (env->ExceptionCheck()) {
            wipe(samples);
            return nullptr;
        }

        // Same orchestration as crispasr_session_transcribe_chunked(): bounded ~30 s windows keep
        // encoder memory flat for long dictations, and the gap-fill pass recovers dropped spans.
        parakeet_orchestrate_opts options;
        options.chunked_requested = true;
        options.chunk_overlap_seconds = 2.0f;
        options.no_prints = true;
        segments = parakeet_transcribe_segments(context, samples.data(), sample_count, 0, false, options);
        wipe(samples);

        for (auto &segment : segments) {
            const std::string text = trim(segment.text);
            if (text.empty()) continue;
            if (!transcript.empty()) transcript.push_back(' ');
            transcript.append(text);
        }
        for (auto &segment : segments) {
            wipe(segment.text);
            for (auto &word : segment.words) wipe(word.text);
            for (auto &token : segment.tokens) wipe(token.text);
        }
        segments.clear();
    } catch (const std::bad_alloc &) {
        wipe(samples);
        segments.clear();
        wipe(transcript);
        throwJavaException(env, "Phonon-2 ran out of memory. Try a shorter dictation or use Whisper.");
        return nullptr;
    } catch (const std::exception &) {
        wipe(samples);
        segments.clear();
        wipe(transcript);
        throwJavaException(env, "Local Phonon-2 transcription failed.");
        return nullptr;
    }

    jbyteArray result = env->NewByteArray(static_cast<jsize>(transcript.size()));
    if (result != nullptr && !transcript.empty()) {
        env->SetByteArrayRegion(
            result, 0, static_cast<jsize>(transcript.size()), reinterpret_cast<const jbyte *>(transcript.data())
        );
    }
    wipe(transcript);
    return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_talkies_android_LocalPhonon_nativeUnload(JNIEnv * /* env */, jobject /* receiver */) {
    std::lock_guard<std::mutex> lock(runtime_mutex);
    unloadLocked();
}
