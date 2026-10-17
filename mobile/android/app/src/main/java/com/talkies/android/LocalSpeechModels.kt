package com.talkies.android

import android.content.SharedPreferences
import java.io.File

/** Composition root for on-device speech recognition, shared by the app screen and the keyboard. */
internal class LocalSpeechModels(filesDir: File) {
    private val modelsDirectory = File(filesDir, "models")
    val whisperStore = WhisperTinyModelStore(modelsDirectory)
    val phononStore = Phonon2ModelStore(File(modelsDirectory, Phonon2ModelStore.DIRECTORY_NAME))
    private val whisper = WhisperTinyRecognizer(whisperStore)
    private val phonon = Phonon2Recognizer(phononStore)
    val chain = SpeechRecognizerChain(listOf(phonon, whisper))

    /** False when this device cannot load the Phonon-2 native runtime; Whisper tiny still works. */
    val phononRuntimeSupported: Boolean get() = phonon.isRuntimeSupported
}

internal object SpeechSettings {
    const val PREFERENCES = "talkies-settings"
    private const val ENGINE_KEY = "speech-engine"

    fun enginePreference(preferences: SharedPreferences): SpeechEnginePreference =
        SpeechEnginePreference.fromStoredValue(preferences.getString(ENGINE_KEY, null))

    fun setEnginePreference(preferences: SharedPreferences, preference: SpeechEnginePreference) {
        preferences.edit().putString(ENGINE_KEY, preference.name).apply()
    }
}

/** User-facing text for speech-engine results. Kept free of Android types so it is unit-tested. */
internal object SpeechStatusText {
    val PHONON_DOWNLOAD_SIZE: String = formatDownloadSize(Phonon2ModelStore.DOWNLOAD_SIZE_BYTES)
    val WHISPER_DOWNLOAD_SIZE: String = formatDownloadSize(WhisperTinyModelStore.MODEL_SIZE_BYTES)

    fun completed(outcome: SpeechRecognitionOutcome, preference: SpeechEnginePreference): String {
        val engine = outcome.engine.label
        return when {
            outcome.failures.isNotEmpty() ->
                "${outcome.failures.first().engine.label} failed, so $engine transcribed locally."
            preference == SpeechEnginePreference.PHONON_2 && outcome.engine != SpeechEngine.PHONON_2 ->
                "Phonon-2 is not ready, so $engine transcribed locally."
            else -> "Transcription complete. $engine ran locally."
        }
    }

    /** Short keyboard status after insertion. */
    fun inserted(outcome: SpeechRecognitionOutcome): String =
        if (outcome.failures.isNotEmpty()) "Inserted ✓ (${outcome.engine.label} fallback)" else "Inserted ✓"

    fun readiness(engines: List<SpeechEngine>, preference: SpeechEnginePreference): String {
        val first = engines.firstOrNull()
        return when {
            first == null && preference == SpeechEnginePreference.WHISPER ->
                "Download Whisper tiny, or choose Automatic, to start dictating."
            first == null -> "Download a local speech model to get started."
            preference == SpeechEnginePreference.PHONON_2 && first != SpeechEngine.PHONON_2 ->
                "Phonon-2 is not ready. Dictation will use ${first.label}."
            else -> "Ready for offline dictation with ${first.label}."
        }
    }

    fun missingModel(preference: SpeechEnginePreference): String = when (preference) {
        SpeechEnginePreference.WHISPER -> "Download Whisper tiny in Talkies first"
        else -> "Download a speech model in Talkies first"
    }

    fun downloadProgress(name: String, downloadedBytes: Long, totalBytes: Long): String =
        "Downloading $name… ${formatDownloadSize(downloadedBytes)} / ${formatDownloadSize(totalBytes)}"

    fun notEnoughStorage(name: String, requiredBytes: Long, availableBytes: Long): String =
        "Not enough free storage for $name: it needs ${formatDownloadSize(requiredBytes)}, " +
            "and ${formatDownloadSize(availableBytes)} is free."
}
