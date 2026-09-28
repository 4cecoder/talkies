package com.talkies.android

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Test

class WhisperTinyRecognizerTest {
    @Test
    fun rejectsMissingModelBeforeCallingNativeRuntime() {
        val directory = Files.createTempDirectory("talkies-missing-model-").toFile()
        try {
            val error = runCatching {
                WhisperTinyRecognizer(WhisperTinyModelStore(directory)).transcribe(floatArrayOf(0f))
            }.exceptionOrNull()

            assertEquals(
                "The local Whisper model is missing or invalid. Open Talkies and download it again.",
                error?.message
            )
        } finally {
            directory.deleteRecursively()
        }
    }
}
