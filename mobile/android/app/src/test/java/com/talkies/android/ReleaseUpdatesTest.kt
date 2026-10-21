package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Test

class ReleaseUpdatesTest {
    @Test fun comparesNumericVersionsRatherThanStrings() {
        assertEquals(1, ReleaseUpdates.compareVersions("0.1.10", "0.1.9"))
        assertEquals(-1, ReleaseUpdates.compareVersions("1.0.0", "1.0.1"))
        assertEquals(0, ReleaseUpdates.compareVersions("1.2", "1.2.0"))
    }
}
