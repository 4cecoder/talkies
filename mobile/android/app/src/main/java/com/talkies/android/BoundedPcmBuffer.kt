package com.talkies.android

/** Holds little-endian PCM16 samples up to a fixed memory limit. */
internal class BoundedPcmBuffer(maxBytes: Int) {
    private val output = WipingPcmOutputStream(initialCapacity(maxBytes), maxBytes)

    private fun initialCapacity(maxBytes: Int): Int {
        require(maxBytes > 0 && maxBytes % BYTES_PER_SAMPLE == 0) {
            "PCM buffer capacity must be a positive whole number of samples."
        }
        return maxBytes.coerceAtMost(INITIAL_CAPACITY_BYTES)
    }

    val sizeBytes: Int get() = output.size()
    val isFull: Boolean get() = sizeBytes == output.maxBytes

    /** Appends as many samples as fit and returns the number accepted. */
    fun append(samples: ShortArray, requestedCount: Int): Int = output.append(samples, requestedCount)

    fun toFloatArray(): FloatArray = output.toFloatArray()

    fun wipe() = output.wipe()

    private class WipingPcmOutputStream(initialCapacity: Int, val maxBytes: Int) :
        java.io.ByteArrayOutputStream(initialCapacity) {

        fun append(samples: ShortArray, requestedCount: Int): Int {
            require(requestedCount in 0..samples.size) { "Invalid PCM sample count." }
            val writableSamples = minOf(requestedCount, (maxBytes - count) / BYTES_PER_SAMPLE)
            ensureCapacity(count + writableSamples * BYTES_PER_SAMPLE)
            for (index in 0 until writableSamples) {
                val sample = samples[index].toInt()
                buf[count++] = (sample and 0xff).toByte()
                buf[count++] = (sample shr 8).toByte()
            }
            return writableSamples
        }

        fun toFloatArray(): FloatArray {
            check(count % BYTES_PER_SAMPLE == 0) { "PCM buffer contains a partial sample." }
            return FloatArray(count / BYTES_PER_SAMPLE) { index ->
                val low = buf[index * 2].toInt() and 0xff
                val high = buf[index * 2 + 1].toInt()
                val sample = (high shl 8) or low
                sample.toShort() / 32768.0f
            }
        }

        fun wipe() {
            buf.fill(0)
            buf = ByteArray(minOf(INITIAL_CAPACITY_BYTES, maxBytes))
            count = 0
        }

        private fun ensureCapacity(requiredBytes: Int) {
            if (requiredBytes <= buf.size) return
            var nextCapacity = buf.size
            while (nextCapacity < requiredBytes) {
                nextCapacity = minOf(maxBytes.toLong(), maxOf(1, nextCapacity).toLong() * 2).toInt()
            }
            val previousBuffer = buf
            buf = previousBuffer.copyOf(nextCapacity)
            previousBuffer.fill(0)
        }
    }

    private companion object {
        const val BYTES_PER_SAMPLE = 2
        const val INITIAL_CAPACITY_BYTES = 64 * 1024
    }
}
