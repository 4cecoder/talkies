package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Test

class SpeechStatusTextTest {
    @Test
    fun downloadButtonsShowTheirSizes() {
        assertEquals("402.2 MB", SpeechStatusText.PHONON_DOWNLOAD_SIZE)
        assertEquals("77.7 MB", SpeechStatusText.WHISPER_DOWNLOAD_SIZE)
        assertEquals(
            "Downloading Phonon-2… 100.0 MB / 402.2 MB",
            SpeechStatusText.downloadProgress("Phonon-2", 100_000_000L, 402_226_656L)
        )
    }

    @Test
    fun completionNamesTheEngineAndAnyFallback() {
        assertEquals(
            "Transcription complete. Phonon-2 ran locally.",
            SpeechStatusText.completed(outcome(SpeechEngine.PHONON_2), SpeechEnginePreference.AUTOMATIC)
        )
        assertEquals(
            "Phonon-2 failed, so Whisper tiny transcribed locally.",
            SpeechStatusText.completed(
                outcome(SpeechEngine.WHISPER_TINY, failed = SpeechEngine.PHONON_2),
                SpeechEnginePreference.AUTOMATIC
            )
        )
        assertEquals(
            "Phonon-2 is not ready, so Whisper tiny transcribed locally.",
            SpeechStatusText.completed(
                outcome(SpeechEngine.WHISPER_TINY, unavailable = SpeechEngine.PHONON_2),
                SpeechEnginePreference.PHONON_2
            )
        )
        assertEquals(
            "Transcription complete. Whisper tiny ran locally.",
            SpeechStatusText.completed(
                outcome(SpeechEngine.WHISPER_TINY, unavailable = SpeechEngine.PHONON_2),
                SpeechEnginePreference.AUTOMATIC
            )
        )
    }

    @Test
    fun readinessExplainsWhatTheUserNeeds() {
        assertEquals(
            "Download a local speech model to get started.",
            SpeechStatusText.readiness(emptyList(), SpeechEnginePreference.AUTOMATIC)
        )
        assertEquals(
            "Download Whisper tiny, or choose Automatic, to start dictating.",
            SpeechStatusText.readiness(emptyList(), SpeechEnginePreference.WHISPER)
        )
        assertEquals(
            "Phonon-2 is not ready. Dictation will use Whisper tiny.",
            SpeechStatusText.readiness(listOf(SpeechEngine.WHISPER_TINY), SpeechEnginePreference.PHONON_2)
        )
        assertEquals(
            "Ready for offline dictation with Phonon-2.",
            SpeechStatusText.readiness(
                listOf(SpeechEngine.PHONON_2, SpeechEngine.WHISPER_TINY),
                SpeechEnginePreference.AUTOMATIC
            )
        )
    }

    @Test
    fun storageMessageShowsBothSizes() {
        assertEquals(
            "Not enough free storage for Phonon-2: it needs 402.2 MB, and 50.0 MB is free.",
            SpeechStatusText.notEnoughStorage("Phonon-2", 402_248_054L, 50_000_000L)
        )
    }

    private fun outcome(
        engine: SpeechEngine,
        failed: SpeechEngine? = null,
        unavailable: SpeechEngine? = null,
    ) = SpeechRecognitionOutcome(
        transcript = "text",
        engine = engine,
        unavailable = listOfNotNull(unavailable),
        failures = listOfNotNull(failed?.let { SpeechEngineFailure(it, IllegalStateException("boom")) }),
    )
}
