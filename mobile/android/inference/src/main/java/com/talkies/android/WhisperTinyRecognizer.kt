package com.talkies.android

/** Local whisper.cpp adapter. The model store and JNI runtime stay inside the inference module. */
class WhisperTinyRecognizer(private val modelStore: WhisperTinyModelStore) : SpeechRecognizer {
    override fun transcribe(audioSamples: FloatArray): String {
        check(modelStore.isInstalled()) { "The local Whisper model is missing or invalid. Open Talkies and download it again." }
        return LocalWhisper.transcribe(modelStore.modelFile.absolutePath, audioSamples)
    }
}
