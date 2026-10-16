package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SpeechEngineSelectionTest {
    @Test
    fun automaticAndPhononPreferPhononThenWhisper() {
        val expected = listOf(SpeechEngine.PHONON_2, SpeechEngine.WHISPER_TINY)
        assertEquals(expected, SpeechEngineSelection.order(SpeechEnginePreference.AUTOMATIC))
        assertEquals(expected, SpeechEngineSelection.order(SpeechEnginePreference.PHONON_2))
    }

    @Test
    fun choosingWhisperNeverRunsPhonon() {
        assertEquals(listOf(SpeechEngine.WHISPER_TINY), SpeechEngineSelection.order(SpeechEnginePreference.WHISPER))
        assertEquals(
            emptyList<SpeechEngine>(),
            SpeechEngineSelection.plan(SpeechEnginePreference.WHISPER) { it == SpeechEngine.PHONON_2 }
        )
    }

    @Test
    fun planSkipsUnavailableEngines() {
        assertEquals(
            listOf(SpeechEngine.WHISPER_TINY),
            SpeechEngineSelection.plan(SpeechEnginePreference.AUTOMATIC) { it == SpeechEngine.WHISPER_TINY }
        )
        assertEquals(
            listOf(SpeechEngine.PHONON_2),
            SpeechEngineSelection.plan(SpeechEnginePreference.PHONON_2) { it == SpeechEngine.PHONON_2 }
        )
    }

    @Test
    fun storedPreferenceDefaultsToAutomatic() {
        assertEquals(SpeechEnginePreference.AUTOMATIC, SpeechEnginePreference.fromStoredValue(null))
        assertEquals(SpeechEnginePreference.AUTOMATIC, SpeechEnginePreference.fromStoredValue("PARAKEET"))
        assertEquals(SpeechEnginePreference.WHISPER, SpeechEnginePreference.fromStoredValue("WHISPER"))
        assertEquals(SpeechEnginePreference.PHONON_2, SpeechEnginePreference.fromStoredValue("PHONON_2"))
    }

    @Test
    fun chainUsesPhononWhenAvailable() {
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, result = "phonon text")
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, result = "whisper text")
        val outcome = SpeechRecognizerChain(listOf(whisper, phonon))
            .transcribe(floatArrayOf(0.1f), SpeechEnginePreference.AUTOMATIC)

        assertEquals("phonon text", outcome.transcript)
        assertEquals(SpeechEngine.PHONON_2, outcome.engine)
        assertFalse(outcome.usedFallback)
        assertEquals(0, whisper.calls)
    }

    @Test
    fun chainFallsBackToWhisperWhenPhononIsMissing() {
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, available = false)
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, result = "whisper text")
        val outcome = SpeechRecognizerChain(listOf(phonon, whisper))
            .transcribe(floatArrayOf(0.1f), SpeechEnginePreference.AUTOMATIC)

        assertEquals(SpeechEngine.WHISPER_TINY, outcome.engine)
        assertEquals(listOf(SpeechEngine.PHONON_2), outcome.unavailable)
        assertTrue(outcome.failures.isEmpty())
        assertEquals(0, phonon.calls)
    }

    @Test
    fun chainFallsBackToWhisperWhenPhononFails() {
        val failure = IllegalStateException("Phonon-2 could not load the local model.")
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, error = failure)
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, result = "whisper text")
        val samples = floatArrayOf(0.25f, -0.25f)
        val outcome = SpeechRecognizerChain(listOf(phonon, whisper))
            .transcribe(samples, SpeechEnginePreference.PHONON_2)

        assertEquals("whisper text", outcome.transcript)
        assertEquals(SpeechEngine.WHISPER_TINY, outcome.engine)
        assertEquals(listOf(SpeechEngine.PHONON_2), outcome.failures.map { it.engine })
        assertSame(failure, outcome.failures.single().error)
        assertSame("Both runtimes see the same caller-owned buffer", samples, whisper.lastSamples)
    }

    @Test
    fun blankPhononTranscriptIsSilenceNotAFailure() {
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, result = "")
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, result = "hallucination")
        val outcome = SpeechRecognizerChain(listOf(phonon, whisper))
            .transcribe(floatArrayOf(0f), SpeechEnginePreference.AUTOMATIC)

        assertEquals("", outcome.transcript)
        assertEquals(SpeechEngine.PHONON_2, outcome.engine)
        assertEquals(0, whisper.calls)
    }

    @Test
    fun whisperPreferenceDoesNotFallBackToPhonon() {
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, result = "phonon text")
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, available = false)
        try {
            SpeechRecognizerChain(listOf(phonon, whisper)).transcribe(floatArrayOf(0f), SpeechEnginePreference.WHISPER)
            fail("Expected no engine to be available")
        } catch (error: NoSpeechEngineAvailableException) {
            assertEquals(listOf(SpeechEngine.WHISPER_TINY), error.unavailable)
            assertEquals("Whisper tiny is not downloaded. Download it or choose Automatic.", error.message)
        }
        assertEquals(0, phonon.calls)
    }

    @Test
    fun allEnginesFailingReportsTheLastError() {
        val phonon = FakeRuntime(SpeechEngine.PHONON_2, error = IllegalStateException("phonon broke"))
        val whisper = FakeRuntime(SpeechEngine.WHISPER_TINY, error = IllegalStateException("whisper broke"))
        try {
            SpeechRecognizerChain(listOf(phonon, whisper)).transcribe(floatArrayOf(0f), SpeechEnginePreference.AUTOMATIC)
            fail("Expected both engines to fail")
        } catch (error: NoSpeechEngineAvailableException) {
            assertEquals(listOf(SpeechEngine.PHONON_2, SpeechEngine.WHISPER_TINY), error.failures.map { it.engine })
            assertEquals("Local transcription failed: whisper broke", error.message)
        }
    }

    @Test
    fun noModelsGivesADownloadPrompt() {
        val chain = SpeechRecognizerChain(
            listOf(
                FakeRuntime(SpeechEngine.PHONON_2, available = false),
                FakeRuntime(SpeechEngine.WHISPER_TINY, available = false)
            )
        )
        assertTrue(chain.plan(SpeechEnginePreference.AUTOMATIC).isEmpty())
        val error = runCatching { chain.transcribe(floatArrayOf(0f), SpeechEnginePreference.AUTOMATIC) }.exceptionOrNull()
        assertEquals("Download a local speech model before dictating.", error?.message)
    }

    @Test(expected = IllegalArgumentException::class)
    fun duplicateEnginesAreRejected() {
        SpeechRecognizerChain(
            listOf(FakeRuntime(SpeechEngine.WHISPER_TINY), FakeRuntime(SpeechEngine.WHISPER_TINY))
        )
    }

    @Test
    fun downloadSizesAreShownInMegabytes() {
        assertEquals("402.2 MB", formatDownloadSize(402_226_656L))
        assertEquals("77.7 MB", formatDownloadSize(77_691_713L))
        assertEquals("1.26 GB", formatDownloadSize(1_255_339_232L))
    }

    private class FakeRuntime(
        override val engine: SpeechEngine,
        private val available: Boolean = true,
        private val result: String = "",
        private val error: Exception? = null,
    ) : LocalSpeechRuntime {
        var calls = 0
        var lastSamples: FloatArray? = null

        override fun isAvailable(): Boolean = available

        override fun transcribe(audioSamples: FloatArray): String {
            calls += 1
            lastSamples = audioSamples
            error?.let { throw it }
            return result
        }
    }
}
