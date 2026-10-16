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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Real Phonon-2 recognition through CrispASR with networking disabled. Skipped unless the pinned
 * Phonon-2 weights, LICENSE, and NOTICE are pre-provisioned under
 * files/models/Phonon-2-<revision>/, together with files/fixtures/jfk.wav.
 */
@RunWith(AndroidJUnit4::class)
class LocalPhononOfflineAcceptanceTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context: Context = instrumentation.targetContext

    @Test
    fun phonon2TranscribesTheSharedFixtureWithNetworkingDisabled() {
        val models = LocalSpeechModels(context.filesDir)
        assumeTrue("Phonon-2 is not provisioned on this device", models.phononStore.isInstalled())
        assertTrue("libtalkies_phonon.so must load on supported ABIs", models.phononRuntimeSupported)
        val samples = readFixture()

        try {
            enableAirplaneMode()
            val transcript = Phonon2Recognizer(models.phononStore).transcribe(samples)
            assertTrue("Phonon-2 did not recognize the JFK fixture: $transcript", transcript.contains("country", ignoreCase = true))
        } finally {
            samples.fill(0f)
            setAirplaneMode(enabled = false)
        }
    }

    @Test
    fun automaticPrefersPhononAndWhisperRemainsSelectable() {
        val models = LocalSpeechModels(context.filesDir)
        assumeTrue("Phonon-2 is not provisioned on this device", models.phononStore.isInstalled())
        assumeTrue("Whisper tiny is not provisioned on this device", models.whisperStore.isInstalled())
        val samples = readFixture()

        try {
            enableAirplaneMode()
            val automatic = models.chain.transcribe(samples, SpeechEnginePreference.AUTOMATIC)
            assertEquals(SpeechEngine.PHONON_2, automatic.engine)
            assertTrue(automatic.failures.isEmpty())

            val whisper = models.chain.transcribe(samples, SpeechEnginePreference.WHISPER)
            assertEquals(SpeechEngine.WHISPER_TINY, whisper.engine)
            assertTrue("Whisper output: ${whisper.transcript}", whisper.transcript.contains("country", ignoreCase = true))
        } finally {
            samples.fill(0f)
            setAirplaneMode(enabled = false)
        }
    }

    private fun readFixture(): FloatArray {
        val fixture = File(context.filesDir, "fixtures/jfk.wav")
        assumeTrue("The shared WAV fixture is not provisioned", fixture.isFile)
        val bytes = fixture.readBytes()
        require(bytes.size >= WAV_HEADER_BYTES && bytes.copyOfRange(0, 4).decodeToString() == "RIFF")
        val header = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        require(header.getShort(22).toInt() == 1 && header.getInt(24) == 16_000 && header.getShort(34).toInt() == 16)
        return FloatArray((bytes.size - WAV_HEADER_BYTES) / 2) { index ->
            header.getShort(WAV_HEADER_BYTES + index * 2) / 32768.0f
        }
    }

    private fun enableAirplaneMode() {
        setAirplaneMode(enabled = true)
        SystemClock.sleep(1_500)
        assertEquals(1, Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0))
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        assertNull("Airplane mode left an active network available", connectivity.activeNetwork)
    }

    private fun setAirplaneMode(enabled: Boolean) {
        val action = if (enabled) "enable" else "disable"
        val descriptor = instrumentation.uiAutomation.executeShellCommand("cmd connectivity airplane-mode $action")
        ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { it.readBytes() }
    }

    private companion object {
        const val WAV_HEADER_BYTES = 44
    }
}
