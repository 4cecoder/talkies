package com.talkies.android

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import kotlin.math.max

/** Captures ephemeral 16 kHz mono PCM in memory for local Whisper inference. */
internal class OfflineAudioCapture {
    @Volatile private var capturing = false
    @Volatile private var captureError: String? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private val pcmBuffer = BoundedPcmBuffer(MAX_PCM_BYTES)

    @SuppressLint("MissingPermission")
    @Synchronized
    fun start(onMaximumDurationReached: () -> Unit = {}) {
        check(!capturing) { "Recording is already active." }
        val minBufferBytes = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        check(minBufferBytes > 0) { "This device could not configure microphone capture." }

        pcmBuffer.wipe()
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
        captureThread = Thread(
            { captureLoop(record, onMaximumDurationReached) },
            "TalkiesAudioCapture"
        ).apply { start() }
    }

    @Synchronized
    fun stop(): FloatArray {
        val record = audioRecord ?: error("Recording is not active.")
        capturing = false
        runCatching { record.stop() }
        try {
            captureThread?.join()
            captureError?.let { error(it) }
            check(pcmBuffer.sizeBytes >= MINIMUM_AUDIO_BYTES) {
                "Not enough audio was recorded. Try speaking for longer."
            }
            return pcmBuffer.toFloatArray()
        } finally {
            record.release()
            audioRecord = null
            captureThread = null
            pcmBuffer.wipe()
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
            pcmBuffer.wipe()
        }
    }

    private fun captureLoop(record: AudioRecord, onMaximumDurationReached: () -> Unit) {
        val samples = ShortArray(4096)
        try {
            while (capturing) {
                val count = record.read(samples, 0, samples.size, AudioRecord.READ_BLOCKING)
                if (count > 0) {
                    val acceptedSamples = pcmBuffer.append(samples, count)
                    if (acceptedSamples < count || pcmBuffer.isFull) {
                        capturing = false
                        runCatching { record.stop() }
                        onMaximumDurationReached()
                    }
                } else if (capturing) {
                    captureError = "Microphone capture stopped unexpectedly ($count)."
                    capturing = false
                }
            }
        } finally {
            samples.fill(0)
        }
    }

    companion object {
        const val MAX_RECORDING_SECONDS = 5 * 60
        private const val SAMPLE_RATE = 16_000
        private const val MINIMUM_AUDIO_BYTES = SAMPLE_RATE / 2 * 2
        private const val MAX_PCM_BYTES = SAMPLE_RATE * MAX_RECORDING_SECONDS * 2
    }
}
