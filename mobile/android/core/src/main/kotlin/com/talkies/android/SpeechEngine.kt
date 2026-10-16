package com.talkies.android

/** On-device speech-recognition runtimes Talkies can use. */
enum class SpeechEngine(val label: String) {
    PHONON_2("Phonon-2"),
    WHISPER_TINY("Whisper tiny"),
}

/** The user's speech-engine setting. Persisted by [name]. */
enum class SpeechEnginePreference(val label: String) {
    AUTOMATIC("Automatic"),
    PHONON_2("Phonon-2"),
    WHISPER("Whisper"),
    ;

    companion object {
        /** Unknown or missing stored values select [AUTOMATIC]. */
        fun fromStoredValue(value: String?): SpeechEnginePreference =
            entries.firstOrNull { it.name == value } ?: AUTOMATIC
    }
}

/** A local recognizer that can say whether its verified model and native runtime are usable right now. */
interface LocalSpeechRuntime : SpeechRecognizer {
    val engine: SpeechEngine

    /** May read and hash model files; call it off the main thread. */
    fun isAvailable(): Boolean
}

/** Pure policy: which engines to try, in order, for a preference. */
object SpeechEngineSelection {
    /**
     * Automatic and Phonon-2 both prefer Phonon-2 and fall back to Whisper tiny when Phonon-2 is
     * missing, cannot load, or fails. Choosing Whisper uses only Whisper tiny.
     */
    fun order(preference: SpeechEnginePreference): List<SpeechEngine> = when (preference) {
        SpeechEnginePreference.AUTOMATIC,
        SpeechEnginePreference.PHONON_2 -> listOf(SpeechEngine.PHONON_2, SpeechEngine.WHISPER_TINY)
        SpeechEnginePreference.WHISPER -> listOf(SpeechEngine.WHISPER_TINY)
    }

    /** The engines that would be attempted, given the caller-supplied availability. */
    fun plan(preference: SpeechEnginePreference, isAvailable: (SpeechEngine) -> Boolean): List<SpeechEngine> =
        order(preference).filter(isAvailable)
}

/** An engine that was available but threw while transcribing. */
data class SpeechEngineFailure(val engine: SpeechEngine, val error: Exception)

/**
 * The transcript and the engine that produced it. [unavailable] lists preferred engines that were
 * skipped; [failures] lists engines that were tried first and failed.
 */
data class SpeechRecognitionOutcome(
    val transcript: String,
    val engine: SpeechEngine,
    val unavailable: List<SpeechEngine>,
    val failures: List<SpeechEngineFailure>,
) {
    val usedFallback: Boolean get() = failures.isNotEmpty() || unavailable.isNotEmpty()
}

class NoSpeechEngineAvailableException(
    val preference: SpeechEnginePreference,
    val unavailable: List<SpeechEngine>,
    val failures: List<SpeechEngineFailure>,
) : IllegalStateException(
    failures.lastOrNull()?.error?.message?.let { "Local transcription failed: $it" }
        ?: when (preference) {
            SpeechEnginePreference.WHISPER -> "Whisper tiny is not downloaded. Download it or choose Automatic."
            else -> "Download a local speech model before dictating."
        }
)

/**
 * Runs the ordered runtime chain for a preference. A blank transcript is a valid result (silence)
 * and does not trigger a fallback; only an exception from an available runtime does.
 */
class SpeechRecognizerChain(runtimes: List<LocalSpeechRuntime>) {
    private val byEngine: Map<SpeechEngine, LocalSpeechRuntime> = runtimes.associateBy { it.engine }

    init {
        require(byEngine.size == runtimes.size) { "Each speech engine may be registered once." }
    }

    /** Engines that are usable for [preference], in the order they would run. Call off the main thread. */
    fun plan(preference: SpeechEnginePreference): List<SpeechEngine> =
        SpeechEngineSelection.plan(preference) { byEngine[it]?.isAvailable() == true }

    fun transcribe(audioSamples: FloatArray, preference: SpeechEnginePreference): SpeechRecognitionOutcome {
        val unavailable = mutableListOf<SpeechEngine>()
        val failures = mutableListOf<SpeechEngineFailure>()
        for (engine in SpeechEngineSelection.order(preference)) {
            val runtime = byEngine[engine]
            if (runtime == null || !runtime.isAvailable()) {
                unavailable += engine
                continue
            }
            try {
                val transcript = runtime.transcribe(audioSamples)
                return SpeechRecognitionOutcome(transcript, engine, unavailable.toList(), failures.toList())
            } catch (error: Exception) {
                failures += SpeechEngineFailure(engine, error)
            }
        }
        throw NoSpeechEngineAvailableException(preference, unavailable.toList(), failures.toList())
    }
}

/** Formats a download size for display, for example "402.2 MB". Uses SI megabytes like Android's file sizes. */
fun formatDownloadSize(bytes: Long): String {
    require(bytes >= 0) { "Download size cannot be negative." }
    val megabytes = bytes / 1_000_000.0
    return if (megabytes >= 1000) {
        "%.2f GB".format(java.util.Locale.ROOT, megabytes / 1000)
    } else {
        "%.1f MB".format(java.util.Locale.ROOT, megabytes)
    }
}
