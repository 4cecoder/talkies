package com.talkies.android

/** Transcribes in-memory audio without exposing a platform or native runtime API. */
fun interface SpeechRecognizer {
    fun transcribe(audioSamples: FloatArray): String
}
