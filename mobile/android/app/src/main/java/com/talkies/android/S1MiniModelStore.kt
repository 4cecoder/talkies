package com.talkies.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.net.URL
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import javax.net.ssl.HttpsURLConnection

internal data class S1MiniDownloadProgress(val downloadedBytes: Long, val totalBytes: Long)

/** Stores verified S1-mini weights and the model's required attribution files on-device. */
internal class S1MiniModelStore(private val directory: File) {
    val modelFile: File get() = File(directory, MODEL_FILENAME)
    private val licenseFile: File get() = File(directory, LICENSE_FILENAME)
    private val noticeFile: File get() = File(directory, NOTICE_FILENAME)
    private var verifiedFingerprint: Pair<Long, Long>? = null

    @Synchronized
    fun isInstalled(): Boolean {
        val fingerprint = modelFile.length() to modelFile.lastModified()
        val modelVerified = fingerprint == verifiedFingerprint ||
            VerifiedModelInstaller.isVerified(modelFile, MODEL_SIZE_BYTES, MODEL_SHA256)
        if (modelVerified) verifiedFingerprint = fingerprint
        return modelVerified && attributionFilesPresent()
    }

    suspend fun download(onProgress: (S1MiniDownloadProgress) -> Unit): File = withContext(Dispatchers.IO) {
        check(directory.isDirectory || directory.mkdirs()) { "Could not create the S1-mini model directory." }
        if (!isModelVerified()) {
            val connection = openConnection(MODEL_FILENAME)
            try {
                connection.connect()
                check(connection.responseCode in 200..299) {
                    "S1-mini download failed (${connection.responseCode})."
                }
                VerifiedModelInstaller.install(
                    input = connection.inputStream,
                    destination = modelFile,
                    expectedSize = MODEL_SIZE_BYTES,
                    expectedSha256 = MODEL_SHA256,
                    onProgress = { downloaded -> onProgress(S1MiniDownloadProgress(downloaded, MODEL_SIZE_BYTES)) }
                )
                rememberVerifiedModel()
            } finally {
                connection.disconnect()
            }
        }
        downloadAttributionIfNeeded(LICENSE_FILENAME)
        downloadAttributionIfNeeded(NOTICE_FILENAME)
        check(isInstalled()) { "S1-mini failed its final integrity or attribution check." }
        modelFile
    }

    fun delete(): Boolean {
        LocalWhisper.unloadCleanupModel()
        verifiedFingerprint = null
        val partialFilesRemoved = listOf(modelFile, licenseFile, noticeFile)
            .map { VerifiedModelInstaller.partialFile(it) }
            .map { !it.exists() || it.delete() }
            .all { it }
        val modelRemoved = !modelFile.exists() || modelFile.delete()
        val licenseRemoved = !licenseFile.exists() || licenseFile.delete()
        val noticeRemoved = !noticeFile.exists() || noticeFile.delete()
        val attributionRemoved = licenseRemoved && noticeRemoved
        return partialFilesRemoved && modelRemoved && attributionRemoved
    }

    private fun downloadAttributionIfNeeded(name: String) {
        val destination = File(directory, name)
        if (destination.isFile && destination.length() > 0) return

        val connection = openConnection(name)
        val partial = VerifiedModelInstaller.partialFile(destination)
        try {
            connection.connect()
            check(connection.responseCode in 200..299) {
                "S1-mini attribution download failed (${connection.responseCode})."
            }
            connection.inputStream.use { input ->
                FileOutputStream(partial).use { output -> input.copyTo(output) }
            }
            check(partial.isFile && partial.length() > 0) { "S1-mini attribution file $name is empty." }
            try {
                Files.move(partial.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
            } catch (_: java.nio.file.AtomicMoveNotSupportedException) {
                Files.move(partial.toPath(), destination.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
        } finally {
            connection.disconnect()
            partial.delete()
        }
    }

    private fun openConnection(name: String): HttpsURLConnection {
        val url = URL("$MODEL_BASE_URL/${MODEL_REVISION}/$name?download=true")
        return (url.openConnection() as HttpsURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 1_800_000
            instanceFollowRedirects = true
            useCaches = false
        }
    }

    @Synchronized
    private fun isModelVerified(): Boolean {
        val fingerprint = modelFile.length() to modelFile.lastModified()
        if (fingerprint == verifiedFingerprint) return true
        if (!VerifiedModelInstaller.isVerified(modelFile, MODEL_SIZE_BYTES, MODEL_SHA256)) return false
        verifiedFingerprint = fingerprint
        return true
    }

    @Synchronized
    private fun rememberVerifiedModel() {
        verifiedFingerprint = modelFile.length() to modelFile.lastModified()
    }

    private fun attributionFilesPresent(): Boolean =
        licenseFile.isFile && licenseFile.length() > 0 &&
            noticeFile.isFile && noticeFile.length() > 0

    companion object {
        const val MODEL_FILENAME = "s1-mini-q4_k_m.gguf"
        const val MODEL_SIZE_BYTES = 484_219_808L
        const val MODEL_SHA256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634"
        const val MODEL_REVISION = "34add00a48a2e5d24e5a4ee5405a99620a3a240c"
        const val LICENSE_FILENAME = "LICENSE"
        const val NOTICE_FILENAME = "NOTICE"
        private const val MODEL_BASE_URL = "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve"
    }
}
