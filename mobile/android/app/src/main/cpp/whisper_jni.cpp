#include <jni.h>
#include <algorithm>
#include <string>
#include <unistd.h>

#include "whisper.h"

namespace {

void throwJavaException(JNIEnv *env, const char *message) {
    jclass exception = env->FindClass("java/lang/IllegalStateException");
    if (exception != nullptr) {
        env->ThrowNew(exception, message);
        env->DeleteLocalRef(exception);
    }
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_talkies_android_LocalWhisper_transcribe(
    JNIEnv *env,
    jobject /* receiver */,
    jstring model_path,
    jfloatArray audio_samples
) {
    if (model_path == nullptr || audio_samples == nullptr) {
        throwJavaException(env, "A verified model and recorded audio are required.");
        return nullptr;
    }

    const char *path = env->GetStringUTFChars(model_path, nullptr);
    if (path == nullptr) return nullptr;

    whisper_context_params context_params = whisper_context_default_params();
    context_params.use_gpu = false;
    whisper_context *context = whisper_init_from_file_with_params(path, context_params);
    env->ReleaseStringUTFChars(model_path, path);
    if (context == nullptr) {
        throwJavaException(env, "Whisper could not load the local model.");
        return nullptr;
    }

    const jsize sample_count = env->GetArrayLength(audio_samples);
    if (sample_count <= 0) {
        whisper_free(context);
        throwJavaException(env, "No audio samples were recorded.");
        return nullptr;
    }
    jfloat *samples = env->GetFloatArrayElements(audio_samples, nullptr);
    if (samples == nullptr) {
        whisper_free(context);
        return nullptr;
    }

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.translate = false;
    params.language = "auto";
    params.n_threads = std::max(2, std::min(4, static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN))));
    params.no_context = true;
    params.single_segment = false;

    const int result = whisper_full(context, params, samples, sample_count);
    env->ReleaseFloatArrayElements(audio_samples, samples, JNI_ABORT);
    if (result != 0) {
        whisper_free(context);
        throwJavaException(env, "Local Whisper transcription failed.");
        return nullptr;
    }

    std::string transcript;
    const int segment_count = whisper_full_n_segments(context);
    for (int index = 0; index < segment_count; ++index) {
        const char *segment = whisper_full_get_segment_text(context, index);
        if (segment != nullptr) transcript.append(segment);
    }
    whisper_free(context);
    return env->NewStringUTF(transcript.c_str());
}
