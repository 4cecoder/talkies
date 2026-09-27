package com.talkies.android

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BoundedPcmBufferTest {
    @Test
    fun appendStopsAtCapacityAndConvertsLittleEndianPcm() {
        val buffer = BoundedPcmBuffer(maxBytes = 4)

        val accepted = buffer.append(shortArrayOf(Short.MIN_VALUE, 0, Short.MAX_VALUE), requestedCount = 3)

        assertEquals(2, accepted)
        assertEquals(4, buffer.sizeBytes)
        assertTrue(buffer.isFull)
        assertArrayEquals(floatArrayOf(-1f, 0f), buffer.toFloatArray(), 0.0001f)
        assertEquals(0, buffer.append(shortArrayOf(1), requestedCount = 1))
    }

    @Test
    fun wipeClearsStoredAudioAndAllowsReuse() {
        val buffer = BoundedPcmBuffer(maxBytes = 4)
        buffer.append(shortArrayOf(12, 34), requestedCount = 2)

        buffer.wipe()

        assertEquals(0, buffer.sizeBytes)
        assertTrue(buffer.toFloatArray().isEmpty())
        assertEquals(1, buffer.append(shortArrayOf(Short.MAX_VALUE), requestedCount = 1))
        assertArrayEquals(floatArrayOf(Short.MAX_VALUE / 32768f), buffer.toFloatArray(), 0.0001f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun capacityMustContainAtLeastOneWholePcmSample() {
        BoundedPcmBuffer(maxBytes = 3)
    }
}
