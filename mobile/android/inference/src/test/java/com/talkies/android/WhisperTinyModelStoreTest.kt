package com.talkies.android

import java.io.ByteArrayInputStream
import java.io.File
import java.io.InputStream
import java.nio.file.Files
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WhisperTinyModelStoreTest {
    @Test
    fun modelMatchesTheSharedPinnedDesktopArtifact() {
        assertEquals(77_691_713L, WhisperTinyModelStore.MODEL_SIZE_BYTES)
        assertEquals(
            "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21",
            WhisperTinyModelStore.MODEL_SHA256
        )
    }

    @Test
    fun installerAtomicallyWritesOnlyAHashVerifiedModel() {
        withTempDirectory { directory ->
            val destination = File(directory, "model.bin")
            val contents = "verified local model".encodeToByteArray()
            val progress = mutableListOf<Long>()

            val installed = VerifiedModelInstaller.install(
                input = ByteArrayInputStream(contents),
                destination = destination,
                expectedSize = contents.size.toLong(),
                expectedSha256 = sha256(contents),
                onProgress = progress::add
            )

            assertEquals(destination, installed)
            assertTrue(VerifiedModelInstaller.isVerified(destination, contents.size.toLong(), sha256(contents)))
            assertEquals(listOf(contents.size.toLong()), progress)
            assertFalse(VerifiedModelInstaller.partialFile(destination).exists())
        }
    }

    @Test
    fun badHashDoesNotReplaceAnExistingModelOrLeavePartialData() {
        withTempDirectory { directory ->
            val destination = File(directory, "model.bin")
            destination.writeText("existing model")
            val previousContents = destination.readBytes()
            val replacement = "untrusted download".encodeToByteArray()

            val result = runCatching {
                VerifiedModelInstaller.install(
                    input = ByteArrayInputStream(replacement),
                    destination = destination,
                    expectedSize = replacement.size.toLong(),
                    expectedSha256 = "0".repeat(64)
                )
            }

            assertTrue(result.isFailure)
            assertTrue(destination.readBytes().contentEquals(previousContents))
            assertFalse(VerifiedModelInstaller.partialFile(destination).exists())
        }
    }

    @Test
    fun interruptedAndOversizedDownloadsAreDiscarded() {
        withTempDirectory { directory ->
            val destination = File(directory, "model.bin")
            val interruptedStream = object : InputStream() {
                private var reads = 0
                override fun read(): Int {
                    reads += 1
                    if (reads <= 4) return reads
                    throw java.io.IOException("simulated interrupted download")
                }
            }

            val interrupted = runCatching {
                VerifiedModelInstaller.install(interruptedStream, destination, 8, "0".repeat(64))
            }
            assertTrue(interrupted.isFailure)
            assertFalse(destination.exists())
            assertFalse(VerifiedModelInstaller.partialFile(destination).exists())

            val oversized = runCatching {
                VerifiedModelInstaller.install(
                    ByteArrayInputStream(byteArrayOf(1, 2, 3)),
                    destination,
                    expectedSize = 2,
                    expectedSha256 = "0".repeat(64)
                )
            }
            assertTrue(oversized.isFailure)
            assertFalse(destination.exists())
            assertFalse(VerifiedModelInstaller.partialFile(destination).exists())
        }
    }

    private fun sha256(contents: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(contents)
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }

    private inline fun withTempDirectory(block: (File) -> Unit) {
        val directory = Files.createTempDirectory("talkies-model-test-").toFile()
        try {
            block(directory)
        } finally {
            directory.deleteRecursively()
        }
    }
}
