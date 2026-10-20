package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SshDiscoveryTest {
    @Test
    fun createsProfileFromDiscoveredHostAndAdvertisedUsername() {
        val profile = DiscoveredSshHost("Studio", "192.168.1.8", 2222, "fource")
            .toProfile(usernameFallback = null)
        requireNotNull(profile)
        assertEquals("Studio", profile.name)
        assertEquals("192.168.1.8", profile.host)
        assertEquals(2222, profile.port)
        assertEquals("fource", profile.username)
    }

    @Test
    fun reusesUsernameFromSavedProfileWhenHostDoesNotAdvertiseOne() {
        val profile = DiscoveredSshHost("Build box", "build.local", 22)
            .toProfile(usernameFallback = "dev")
        assertEquals("dev", requireNotNull(profile).username)
    }

    @Test
    fun requiresUsernameOnlyWhenNeitherDiscoveryNorSavedHostsKnowIt() {
        assertNull(DiscoveredSshHost("Build box", "build.local", 22).toProfile(null))
    }
}
