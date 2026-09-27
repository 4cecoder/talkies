package com.talkies.android

import android.content.Context
import android.net.ConnectivityManager
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.Settings
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlinx.coroutines.runBlocking

@RunWith(AndroidJUnit4::class)
class LocalWhisperOfflineAcceptanceTest {
    @Test
    fun cachedWhisperTranscribesFixtureWithExternalNetworkingDisabled() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val model = File(context.filesDir, "models/${WhisperTinyModelStore.MODEL_FILENAME}")
        val fixture = File(context.filesDir, "fixtures/jfk.wav")
        assertTrue("CI must pre-provision the pinned ASR model", WhisperTinyModelStore(context.filesDir.resolve("models")).isInstalled())
        assertTrue("CI must provision the shared WAV fixture", fixture.isFile)
        val samples = readPcm16Mono16kHz(fixture)

        try {
            setAirplaneMode(instrumentation.uiAutomation, enabled = true)
            SystemClock.sleep(1_500)
            assertEquals(1, Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0))
            val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            assertNull("Airplane mode left an active network available", connectivity.activeNetwork)

            val transcript = LocalWhisper.transcribe(model.absolutePath, samples)
            assertTrue("Whisper output did not recognize the shared JFK speech fixture: $transcript", transcript.contains("country", ignoreCase = true))
        } finally {
            samples.fill(0f)
            fixture.delete()
            setAirplaneMode(instrumentation.uiAutomation, enabled = false)
        }
    }

    @Test
    fun cachedS1MiniCleansTranscriptWithExternalNetworkingDisabled() = runBlocking {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val modelDirectory = File(
            context.filesDir,
            "models/S1-mini-${S1MiniModelStore.MODEL_REVISION}"
        )
        val modelStore = S1MiniModelStore(modelDirectory)
        assertTrue("CI must pre-provision the pinned S1-mini model and attribution", modelStore.isInstalled())

        try {
            setAirplaneMode(instrumentation.uiAutomation, enabled = true)
            SystemClock.sleep(1_500)
            assertEquals(1, Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0))
            val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            assertNull("Airplane mode left an active network available", connectivity.activeNetwork)

            val raw = "Um, I think we should meet on Thursday, no, actually Friday."
            val cleaned = S1MiniCleaner(modelStore).clean(raw)
            assertTrue("S1-mini returned no cleaned text", cleaned.isNotBlank())
            assertFalse("S1-mini kept an obvious filler word: $cleaned", Regex("\\bum\\b", RegexOption.IGNORE_CASE).containsMatchIn(cleaned))
            assertTrue("S1-mini lost the corrected day: $cleaned", cleaned.contains("Friday", ignoreCase = true))
        } finally {
            setAirplaneMode(instrumentation.uiAutomation, enabled = false)
        }
    }

    private fun setAirplaneMode(uiAutomation: android.app.UiAutomation, enabled: Boolean) {
        val action = if (enabled) "enable" else "disable"
        val descriptor = uiAutomation.executeShellCommand("cmd connectivity airplane-mode $action")
        ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
    }

    private fun readPcm16Mono16kHz(file: File): FloatArray {
        val bytes = file.readBytes()
        require(bytes.size >= WAV_HEADER_BYTES && bytes.copyOfRange(0, 4).decodeToString() == "RIFF") {
            "The speech fixture must be a RIFF/WAVE file."
        }
        val header = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        require(header.getShort(22).toInt() == 1) { "Whisper fixture must have one audio channel." }
        require(header.getInt(24) == 16_000) { "Whisper fixture must use a 16 kHz sample rate." }
        require(header.getShort(34).toInt() == 16) { "Whisper fixture must use PCM16 samples." }
        require((bytes.size - WAV_HEADER_BYTES) % 2 == 0) { "WAV data must contain complete PCM16 samples." }
        return FloatArray((bytes.size - WAV_HEADER_BYTES) / 2) { index ->
            val sample = header.getShort(WAV_HEADER_BYTES + index * 2)
            sample / 32768.0f
        }
    }

    private companion object {
        const val WAV_HEADER_BYTES = 44
    }
}
