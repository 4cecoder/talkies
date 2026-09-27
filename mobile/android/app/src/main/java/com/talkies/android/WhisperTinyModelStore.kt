package com.talkies.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.URL
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import javax.net.ssl.HttpsURLConnection

internal data class ModelDownloadProgress(val downloadedBytes: Long, val totalBytes: Long)

internal class WhisperTinyModelStore(private val directory: File) {
    val modelFile: File get() = File(directory, MODEL_FILENAME)

    fun isInstalled(): Boolean = VerifiedModelInstaller.isVerified(modelFile, MODEL_SIZE_BYTES, MODEL_SHA256)

    suspend fun download(onProgress: (ModelDownloadProgress) -> Unit): File = withContext(Dispatchers.IO) {
        val connection = (URL(MODEL_URL).openConnection() as HttpsURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 60_000
            instanceFollowRedirects = true
            useCaches = false
        }

        try {
            connection.connect()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Whisper model download failed (${connection.responseCode}).")
            }
            VerifiedModelInstaller.install(
                input = connection.inputStream,
                destination = modelFile,
                expectedSize = MODEL_SIZE_BYTES,
                expectedSha256 = MODEL_SHA256,
                onProgress = { downloaded -> onProgress(ModelDownloadProgress(downloaded, MODEL_SIZE_BYTES)) }
            )
        } finally {
            connection.disconnect()
        }
    }

    fun delete(): Boolean {
        VerifiedModelInstaller.partialFile(modelFile).delete()
        return !modelFile.exists() || modelFile.delete()
    }

    companion object {
        const val MODEL_FILENAME = "ggml-tiny.bin"
        const val MODEL_SIZE_BYTES = 77_691_713L
        const val MODEL_SHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
        private const val MODEL_REVISION = "5359861c739e955e79d9a303bcbc70fb988958b1"
        private const val MODEL_URL =
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/$MODEL_REVISION/$MODEL_FILENAME?download=true"
    }
}

internal object VerifiedModelInstaller {
    private const val PROGRESS_INTERVAL_BYTES = 256 * 1024L

    fun install(
        input: InputStream,
        destination: File,
        expectedSize: Long,
        expectedSha256: String,
        onProgress: (Long) -> Unit = {}
    ): File {
        require(expectedSize > 0) { "Expected model size must be positive." }
        val directory = destination.parentFile ?: error("Model destination must have a parent directory.")
        check(directory.isDirectory || directory.mkdirs()) { "Could not create the model directory." }
        val partial = partialFile(destination)
        partial.delete()
        var installed = false
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            var downloaded = 0L
            var lastProgressReport = 0L
            input.use { source ->
                FileOutputStream(partial).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        downloaded += count
                        check(downloaded <= expectedSize) { "Model download is larger than expected." }
                        digest.update(buffer, 0, count)
                        output.write(buffer, 0, count)
                        if (downloaded - lastProgressReport >= PROGRESS_INTERVAL_BYTES || downloaded == expectedSize) {
                            lastProgressReport = downloaded
                            onProgress(downloaded)
                        }
                    }
                    output.fd.sync()
                }
            }
            check(downloaded == expectedSize && digest.digest().toHexString() == expectedSha256) {
                "Downloaded model failed its size or SHA-256 check."
            }

            try {
                Files.move(
                    partial.toPath(),
                    destination.toPath(),
                    StandardCopyOption.REPLACE_EXISTING,
                    StandardCopyOption.ATOMIC_MOVE
                )
            } catch (_: AtomicMoveNotSupportedException) {
                Files.move(partial.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
            installed = true
            return destination
        } finally {
            if (!installed) partial.delete()
        }
    }

    fun isVerified(file: File, expectedSize: Long, expectedSha256: String): Boolean {
        if (!file.isFile || file.length() != expectedSize) return false
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().toHexString() == expectedSha256
    }

    fun partialFile(destination: File): File = File(destination.parentFile, "${destination.name}.part")

    private fun ByteArray.toHexString(): String {
        val digits = "0123456789abcdef"
        return buildString(size * 2) {
            for (byte in this@toHexString) {
                val value = byte.toInt() and 0xff
                append(digits[value ushr 4])
                append(digits[value and 0x0f])
            }
        }
    }
}
