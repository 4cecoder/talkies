package com.talkies.android

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class AndroidSshCredentialStoreTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun remembersPasswordEncryptedAndBindsItToItsHostProfile() {
        val store = AndroidSshCredentialStore(context)
        val profile = profile()
        val password = "Correct horse 🔐 battery".toCharArray()
        try {
            val directory = File(context.noBackupFilesDir, "ssh-credentials")
            val existing = directory.listFiles().orEmpty().map { it.absolutePath }.toSet()
            store.save(profile, password)
            val files = directory.listFiles()
            assertNotNull(files)
            val encryptedFile = requireNotNull(files).single {
                it.extension == "credential" && it.absolutePath !in existing
            }
            assertFalse(String(encryptedFile.readBytes(), StandardCharsets.UTF_8).contains(String(password)))
            assertArrayEquals(password, requireNotNull(store.load(profile)))

            val changedHost = profile.copy(host = "other.example")
            assertNull(store.load(changedHost))
            assertNull(store.load(profile))
        } finally {
            password.fill('\u0000')
            store.delete(profile.id)
        }
    }

    @Test
    fun deletingAHostCredentialMakesItUnavailable() {
        val store = AndroidSshCredentialStore(context)
        val profile = profile()
        val password = "secret".toCharArray()
        try {
            store.save(profile, password)
            store.delete(profile.id)
            assertNull(store.load(profile))
        } finally {
            password.fill('\u0000')
            store.delete(profile.id)
        }
    }

    private fun profile() = SshHostProfile(
        id = UUID.randomUUID().toString(),
        name = "Test host",
        host = "192.0.2.4",
        port = 2222,
        username = "tester",
    )
}
