package com.talkies.android

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class Phonon2RecognizerTest {
    @Test
    fun missingModelIsUnavailableAndNeverReachesTheRuntime() {
        withTempDirectory { directory ->
            val runtime = FakeRuntime()
            val recognizer = Phonon2Recognizer(Phonon2ModelStore(directory), runtime)

            assertEquals(SpeechEngine.PHONON_2, recognizer.engine)
            assertFalse(recognizer.isAvailable())
            val error = runCatching { recognizer.transcribe(floatArrayOf(0f)) }.exceptionOrNull()
            assertEquals("Phonon-2 is missing or invalid. Open Talkies and download it again.", error?.message)
            assertEquals(0, runtime.transcriptions)
        }
    }

    @Test
    fun unsupportedRuntimeIsUnavailable() {
        withTempDirectory { directory ->
            val recognizer = Phonon2Recognizer(Phonon2ModelStore(directory), FakeRuntime(loaded = false))
            assertFalse(recognizer.isRuntimeSupported)
            assertFalse(recognizer.isAvailable())
            val error = runCatching { recognizer.transcribe(floatArrayOf(0f)) }.exceptionOrNull()
            assertEquals("The Phonon-2 runtime is unavailable on this device.", error?.message)
        }
    }

    @Test
    fun jvmUnitTestsCannotLoadTheNativeLibrary() {
        // Guards the fallback path: a missing libtalkies_phonon.so must not crash class loading.
        assertFalse(LocalPhonon.isLoaded)
        assertFalse(LocalPhonon.canLoad(File("missing.gguf")))
        LocalPhonon.unload()
    }

    private class FakeRuntime(private val loaded: Boolean = true) : PhononRuntime {
        var transcriptions = 0
        override val isLoaded: Boolean get() = loaded
        override fun canLoad(model: File): Boolean = loaded
        override fun transcribe(model: File, audioSamples: FloatArray): String {
            transcriptions += 1
            return "fake"
        }
        override fun unload() = Unit
    }

    private inline fun withTempDirectory(block: (File) -> Unit) {
        val directory = Files.createTempDirectory("talkies-phonon-recognizer-").toFile()
        try {
            block(directory)
        } finally {
            directory.deleteRecursively()
        }
    }
}
