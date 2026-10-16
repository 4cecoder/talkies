package com.talkies.android

/** Local Phonon-2 adapter. CrispASR, JNI, and the verified model store stay inside the inference module. */
class Phonon2Recognizer internal constructor(
    private val modelStore: Phonon2ModelStore,
    private val runtime: PhononRuntime,
) : LocalSpeechRuntime {
    constructor(modelStore: Phonon2ModelStore) : this(modelStore, LocalPhonon)

    override val engine: SpeechEngine = SpeechEngine.PHONON_2

    /** False when `libtalkies_phonon.so` could not be loaded on this device. */
    val isRuntimeSupported: Boolean get() = runtime.isLoaded

    override fun isAvailable(): Boolean =
        runtime.isLoaded && runtime.canLoad(modelStore.modelFile) && modelStore.isInstalled()

    override fun transcribe(audioSamples: FloatArray): String {
        check(runtime.isLoaded) { "The Phonon-2 runtime is unavailable on this device." }
        check(modelStore.isInstalled()) { "Phonon-2 is missing or invalid. Open Talkies and download it again." }
        return runtime.transcribe(modelStore.modelFile, audioSamples)
    }
}
