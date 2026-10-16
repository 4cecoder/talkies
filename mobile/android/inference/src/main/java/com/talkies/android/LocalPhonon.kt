package com.talkies.android

import java.io.File

/** Native Phonon-2 runtime boundary; a fake implements it in unit tests. */
internal interface PhononRuntime {
    /** False when the native library could not be loaded on this device. */
    val isLoaded: Boolean

    /** False after the model at [model] failed to load, until it changes or [unload] is called. */
    fun canLoad(model: File): Boolean

    fun transcribe(model: File, audioSamples: FloatArray): String

    fun unload()
}

/**
 * JNI binding for `libtalkies_phonon.so`: CrispASR's Parakeet TDT backend running Phonon-2.
 *
 * The library is separate from `libtalkies_whisper.so`. If it is missing or fails to load,
 * [isLoaded] is false and dictation falls back to Whisper tiny. The loaded model stays resident
 * between dictations; all native calls are serialized here and inside the library.
 */
internal object LocalPhonon : PhononRuntime {
    override val isLoaded: Boolean = runCatching { System.loadLibrary("talkies_phonon") }.isSuccess

    private var rejectedModel: Triple<String, Long, Long>? = null

    @Synchronized
    override fun canLoad(model: File): Boolean = isLoaded && rejectedModel != fingerprint(model)

    @Synchronized
    override fun transcribe(model: File, audioSamples: FloatArray): String {
        check(isLoaded) { "The Phonon-2 runtime is unavailable on this device." }
        require(audioSamples.isNotEmpty()) { "No audio samples were recorded." }
        val fingerprint = fingerprint(model)
        check(rejectedModel != fingerprint) { "Phonon-2 could not load the local model." }
        if (!nativeLoad(model.absolutePath, threadCount())) {
            rejectedModel = fingerprint
            error("Phonon-2 could not load the local model.")
        }
        return nativeTranscribe(audioSamples).decodeToString()
    }

    @Synchronized
    override fun unload() {
        rejectedModel = null
        if (isLoaded) nativeUnload()
    }

    private fun fingerprint(model: File) = Triple(model.absolutePath, model.length(), model.lastModified())

    private fun threadCount(): Int = Runtime.getRuntime().availableProcessors().coerceIn(2, 4)

    /** Loads [modelPath], reusing the resident context when it is already loaded. */
    private external fun nativeLoad(modelPath: String, threads: Int): Boolean

    /** Returns UTF-8 transcript bytes. The native copy of the PCM is wiped before returning. */
    private external fun nativeTranscribe(audioSamples: FloatArray): ByteArray

    private external fun nativeUnload()
}
