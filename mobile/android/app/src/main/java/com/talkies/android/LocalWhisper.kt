package com.talkies.android

internal object LocalWhisper {
    init {
        System.loadLibrary("talkies_whisper")
    }

    external fun transcribe(modelPath: String, audioSamples: FloatArray): String
}
