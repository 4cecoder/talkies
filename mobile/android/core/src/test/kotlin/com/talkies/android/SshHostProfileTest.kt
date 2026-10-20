package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SshHostProfileTest {
    @Test
    fun acceptsIPv4HostnameAndNonDefaultPort() {
        val profile = SshHostProfile("id", "Beasty", "192.168.1.8", 2222, "fource")
        assertEquals(profile, profile.validate())
        assertEquals("build.example.net", profile.copy(host = "build.example.net").validate().host)
    }

    @Test
    fun rejectsMalformedConnectionFields() {
        val profile = SshHostProfile("id", "Beasty", "host", 22, "fource")
        assertThrows(IllegalArgumentException::class.java) { profile.copy(port = 0).validate() }
        assertThrows(IllegalArgumentException::class.java) { profile.copy(host = "host; id").validate() }
        assertThrows(IllegalArgumentException::class.java) { profile.copy(username = "me user").validate() }
    }

    @Test
    fun neverModelsAnAuthenticationSecret() {
        val names = SshHostProfile::class.java.declaredFields.map { it.name }.toSet()
        assertEquals(setOf("id", "name", "host", "port", "username"), names)
    }
}
