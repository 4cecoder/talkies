package com.talkies.android

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.ByteArrayOutputStream
import kotlin.math.max

/** Captures ephemeral 16 kHz mono PCM in memory for local Whisper inference. */
internal class OfflineAudioCapture {
    @Volatile private var capturing = false
    @Volatile private var captureError: String? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var pcmBytes = WipingByteArrayOutputStream()

    @SuppressLint("MissingPermission")
    @Synchronized
    fun start() {
        check(!capturing) { "Recording is already active." }
        val minBufferBytes = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        check(minBufferBytes > 0) { "This device could not configure microphone capture." }

        pcmBytes = WipingByteArrayOutputStream()
        captureError = null
        val record = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            max(minBufferBytes, SAMPLE_RATE * 2 / 2)
        )
        check(record.state == AudioRecord.STATE_INITIALIZED) {
            record.release()
            "This device could not start microphone capture."
        }

        audioRecord = record
        record.startRecording()
        capturing = true
        captureThread = Thread({ captureLoop(record) }, "TalkiesAudioCapture").apply { start() }
    }

    @Synchronized
    fun stop(): FloatArray {
        val record = audioRecord ?: error("Recording is not active.")
        capturing = false
        runCatching { record.stop() }
        try {
            captureThread?.join()
            captureError?.let { error(it) }
            val bytes = pcmBytes.toByteArray()
            try {
                check(bytes.size >= MINIMUM_AUDIO_BYTES) { "Not enough audio was recorded. Try speaking for longer." }
                return FloatArray(bytes.size / 2) { index ->
                    val low = bytes[index * 2].toInt() and 0xff
                    val high = bytes[index * 2 + 1].toInt()
                    val sample = (high shl 8) or low
                    sample.toShort() / 32768.0f
                }
            } finally {
                bytes.fill(0)
            }
        } finally {
            record.release()
            audioRecord = null
            captureThread = null
            pcmBytes.wipe()
        }
    }

    @Synchronized
    fun cancel() {
        capturing = false
        try {
            audioRecord?.let { record ->
                runCatching { record.stop() }
                runCatching { captureThread?.join() }
                record.release()
            }
        } finally {
            audioRecord = null
            captureThread = null
            pcmBytes.wipe()
        }
    }

    private fun captureLoop(record: AudioRecord) {
        val samples = ShortArray(4096)
        while (capturing) {
            val count = record.read(samples, 0, samples.size, AudioRecord.READ_BLOCKING)
            if (count > 0) {
                for (index in 0 until count) {
                    val sample = samples[index].toInt()
                    pcmBytes.write(sample and 0xff)
                    pcmBytes.write((sample shr 8) and 0xff)
                }
            } else if (capturing) {
                captureError = "Microphone capture stopped unexpectedly ($count)."
                capturing = false
            }
        }
    }

    private companion object {
        const val SAMPLE_RATE = 16_000
        const val MINIMUM_AUDIO_BYTES = SAMPLE_RATE / 2 * 2
    }

    private class WipingByteArrayOutputStream : ByteArrayOutputStream() {
        fun wipe() {
            buf.fill(0)
            reset()
        }
    }
}
