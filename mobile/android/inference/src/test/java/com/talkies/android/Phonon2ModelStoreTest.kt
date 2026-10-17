package com.talkies.android

import java.io.ByteArrayInputStream
import java.io.File
import java.io.InputStream
import java.nio.file.Files
import java.security.MessageDigest
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Phonon2ModelStoreTest {
    @Test
    fun modelIsTheRevisionPinnedAndroidQuantization() {
        assertEquals("cstr/phonon2-GGUF", Phonon2ModelStore.MODEL_REPOSITORY)
        assertEquals("3ed3e6ad6e7ce63affffeede37328ff756efaa2f", Phonon2ModelStore.MODEL_REVISION)
        assertEquals("phonon2-q4_k.gguf", Phonon2ModelStore.MODEL_FILENAME)
        assertEquals(402_226_656L, Phonon2ModelStore.MODEL_SIZE_BYTES)
        assertEquals(
            "c8a55e1009da474f9ae96b1500a6901e739e862cc7b1c3923251bc37e72b16db",
            Phonon2ModelStore.MODEL_SHA256
        )
        assertEquals(Phonon2ModelStore.MODEL_SIZE_BYTES, Phonon2ModelStore.MODEL.sizeBytes)
        assertEquals(Phonon2ModelStore.MODEL_SHA256, Phonon2ModelStore.MODEL.sha256)
    }

    @Test
    fun attributionFilesArePinnedBySizeAndHash() {
        assertEquals(listOf("LICENSE", "NOTICE"), Phonon2ModelStore.ATTRIBUTION.map { it.name })
        assertEquals(listOf(18_657L, 2_741L), Phonon2ModelStore.ATTRIBUTION.map { it.sizeBytes })
        Phonon2ModelStore.ATTRIBUTION.forEach { assertTrue(it.sha256.matches(Regex("[0-9a-f]{64}"))) }
        assertEquals(402_248_054L, Phonon2ModelStore.DOWNLOAD_SIZE_BYTES)
        assertEquals("402.2 MB", formatDownloadSize(Phonon2ModelStore.DOWNLOAD_SIZE_BYTES))
    }

    @Test
    fun downloadsComeFromThePinnedRevisionOverHttps() {
        assertEquals(
            "https://huggingface.co/cstr/phonon2-GGUF/resolve/3ed3e6ad6e7ce63affffeede37328ff756efaa2f/phonon2-q4_k.gguf?download=true",
            Phonon2ModelStore.downloadUrl(Phonon2ModelStore.MODEL_FILENAME)
        )
        assertTrue(Phonon2ModelStore.DIRECTORY_NAME.endsWith(Phonon2ModelStore.MODEL_REVISION))
    }

    @Test
    fun downloadInstallsVerifiedWeightsAndAttribution() = runBlocking {
        withTempDirectory { directory ->
            val fixture = Fixture()
            val progress = mutableListOf<ModelDownloadProgress>()
            val store = fixture.store(directory)

            assertFalse(store.isInstalled())
            val installed = store.download(progress::add)

            assertEquals(File(directory, "model.gguf"), installed)
            assertTrue(store.isInstalled())
            assertEquals(listOf("model.gguf", "LICENSE", "NOTICE"), fixture.opened)
            assertEquals(ModelDownloadProgress(fixture.model.size.toLong(), fixture.model.size.toLong()), progress.last())
            assertEquals("license text", File(directory, "LICENSE").readText())

            fixture.opened.clear()
            store.download {}
            assertTrue("Verified files are not downloaded again", fixture.opened.isEmpty())
        }
    }

    @Test
    fun tamperedAttributionIsNotInstalledAndIsReplacedOnDownload() = runBlocking {
        withTempDirectory { directory ->
            val fixture = Fixture()
            val store = fixture.store(directory)
            store.download {}
            File(directory, "NOTICE").writeText("altered notice")

            assertFalse(store.isInstalled())
            fixture.opened.clear()
            store.download {}
            assertEquals(listOf("NOTICE"), fixture.opened)
            assertTrue(store.isInstalled())
        }
    }

    @Test
    fun corruptDownloadIsRejectedWithoutLeavingFiles() = runBlocking {
        withTempDirectory { directory ->
            val fixture = Fixture(served = mapOf("model.gguf" to "not the pinned weights".encodeToByteArray()))
            val result = runCatching { fixture.store(directory).download {} }

            assertTrue(result.isFailure)
            assertFalse(File(directory, "model.gguf").exists())
            assertFalse(VerifiedModelInstaller.partialFile(File(directory, "model.gguf")).exists())
        }
    }

    @Test
    fun deleteReleasesTheRuntimeBeforeRemovingFiles() = runBlocking {
        withTempDirectory { directory ->
            val events = mutableListOf<String>()
            val fixture = Fixture()
            val store = fixture.store(directory) {
                events += "release:" + File(directory, "model.gguf").exists()
            }
            store.download {}
            File(directory, "model.gguf.part").writeText("stale partial")

            assertTrue(store.delete())
            assertEquals(listOf("release:true"), events)
            assertFalse(store.isInstalled())
            assertTrue(directory.listFiles().orEmpty().isEmpty())
        }
    }

    private class Fixture(served: Map<String, ByteArray> = emptyMap()) {
        val model = "tiny stand-in weights".encodeToByteArray()
        private val license = "license text".encodeToByteArray()
        private val notice = "notice text".encodeToByteArray()
        private val content = mapOf("model.gguf" to model, "LICENSE" to license, "NOTICE" to notice) + served
        val opened = mutableListOf<String>()

        fun store(directory: File, release: () -> Unit = {}) = Phonon2ModelStore(
            directory = directory,
            model = pinned("model.gguf", model),
            attribution = listOf(pinned("LICENSE", license), pinned("NOTICE", notice)),
            openDownload = { file ->
                opened += file.name
                ByteArrayInputStream(content.getValue(file.name)) as InputStream
            },
            releaseRuntime = release,
        )

        private fun pinned(name: String, bytes: ByteArray) = PinnedModelFile(name, bytes.size.toLong(), sha256(bytes))
    }

    private companion object {
        fun sha256(contents: ByteArray): String = MessageDigest.getInstance("SHA-256")
            .digest(contents)
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }

        inline fun withTempDirectory(block: (File) -> Unit) {
            val directory = Files.createTempDirectory("talkies-phonon-test-").toFile()
            try {
                block(directory)
            } finally {
                directory.deleteRecursively()
            }
        }
    }
}
