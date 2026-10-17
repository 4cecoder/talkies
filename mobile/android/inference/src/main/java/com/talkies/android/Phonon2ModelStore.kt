package com.talkies.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FilterInputStream
import java.io.InputStream
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** A downloaded file pinned to an exact byte size and SHA-256 digest. */
data class PinnedModelFile(val name: String, val sizeBytes: Long, val sha256: String)

/**
 * Stores the verified Phonon-2 GGUF weights and their CC-BY-4.0 attribution files on-device.
 *
 * Every file, including LICENSE and NOTICE, is fetched from one pinned Hugging Face revision and
 * must match its exact size and SHA-256 before it is moved into place. Network access happens only
 * inside [download], which the user starts explicitly.
 */
class Phonon2ModelStore internal constructor(
    private val directory: File,
    private val model: PinnedModelFile,
    private val attribution: List<PinnedModelFile>,
    private val openDownload: (PinnedModelFile) -> InputStream,
    private val releaseRuntime: () -> Unit,
) {
    constructor(directory: File) : this(
        directory = directory,
        model = MODEL,
        attribution = ATTRIBUTION,
        openDownload = ::openPinnedHuggingFaceFile,
        releaseRuntime = { LocalPhonon.unload() },
    )

    val modelFile: File get() = File(directory, model.name)
    private var verifiedFingerprints: Map<String, Pair<Long, Long>> = emptyMap()

    /** Hashes files whose size or modification time changed since they were last verified. */
    @Synchronized
    fun isInstalled(): Boolean = (listOf(model) + attribution).all(::isVerified)

    suspend fun download(onProgress: (ModelDownloadProgress) -> Unit): File = withContext(Dispatchers.IO) {
        check(directory.isDirectory || directory.mkdirs()) { "Could not create the Phonon-2 model directory." }
        if (!verify(model)) {
            install(model) { downloaded -> onProgress(ModelDownloadProgress(downloaded, model.sizeBytes)) }
        }
        for (file in attribution) {
            if (!verify(file)) install(file)
        }
        check(isInstalled()) { "Phonon-2 failed its final integrity or attribution check." }
        modelFile
    }

    /** Unloads the native runtime, then removes the weights, attribution files, and partial downloads. */
    fun delete(): Boolean {
        releaseRuntime()
        synchronized(this) { verifiedFingerprints = emptyMap() }
        return (listOf(model) + attribution).map { pinned ->
            val destination = File(directory, pinned.name)
            val partial = VerifiedModelInstaller.partialFile(destination)
            val partialRemoved = !partial.exists() || partial.delete()
            val fileRemoved = !destination.exists() || destination.delete()
            partialRemoved && fileRemoved
        }.all { it }
    }

    private fun install(pinned: PinnedModelFile, onProgress: (Long) -> Unit = {}) {
        VerifiedModelInstaller.install(
            input = openDownload(pinned),
            destination = File(directory, pinned.name),
            expectedSize = pinned.sizeBytes,
            expectedSha256 = pinned.sha256,
            onProgress = onProgress
        )
        remember(pinned)
    }

    @Synchronized
    private fun verify(pinned: PinnedModelFile): Boolean = isVerified(pinned)

    private fun isVerified(pinned: PinnedModelFile): Boolean {
        val file = File(directory, pinned.name)
        val fingerprint = file.length() to file.lastModified()
        if (file.isFile && verifiedFingerprints[pinned.name] == fingerprint) return true
        if (!VerifiedModelInstaller.isVerified(file, pinned.sizeBytes, pinned.sha256)) {
            verifiedFingerprints = verifiedFingerprints - pinned.name
            return false
        }
        verifiedFingerprints = verifiedFingerprints + (pinned.name to fingerprint)
        return true
    }

    @Synchronized
    private fun remember(pinned: PinnedModelFile) {
        val file = File(directory, pinned.name)
        verifiedFingerprints = verifiedFingerprints + (pinned.name to (file.length() to file.lastModified()))
    }

    companion object {
        const val MODEL_REPOSITORY = "cstr/phonon2-GGUF"
        const val MODEL_REVISION = "3ed3e6ad6e7ce63affffeede37328ff756efaa2f"
        const val MODEL_FILENAME = "phonon2-q4_k.gguf"
        const val MODEL_SIZE_BYTES = 402_226_656L
        const val MODEL_SHA256 = "c8a55e1009da474f9ae96b1500a6901e739e862cc7b1c3923251bc37e72b16db"
        const val LICENSE_FILENAME = "LICENSE"
        const val NOTICE_FILENAME = "NOTICE"

        val MODEL = PinnedModelFile(MODEL_FILENAME, MODEL_SIZE_BYTES, MODEL_SHA256)
        val ATTRIBUTION = listOf(
            PinnedModelFile(
                LICENSE_FILENAME,
                18_657L,
                "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411"
            ),
            PinnedModelFile(
                NOTICE_FILENAME,
                2_741L,
                "00624a5043e7ce74029317b024132ca5286116d6fbf3191d226374bc8273789f"
            ),
        )

        /** Bytes the user downloads: the weights plus LICENSE and NOTICE. */
        val DOWNLOAD_SIZE_BYTES: Long = MODEL_SIZE_BYTES + ATTRIBUTION.sumOf { it.sizeBytes }

        /** The model directory name embeds the revision so a future pin never reuses old files. */
        const val DIRECTORY_NAME = "Phonon-2-$MODEL_REVISION"

        internal fun downloadUrl(name: String): String =
            "https://huggingface.co/$MODEL_REPOSITORY/resolve/$MODEL_REVISION/$name?download=true"

        private fun openPinnedHuggingFaceFile(pinned: PinnedModelFile): InputStream {
            val connection = (URL(downloadUrl(pinned.name)).openConnection() as HttpsURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 60_000
                instanceFollowRedirects = true
                useCaches = false
            }
            try {
                connection.connect()
                check(connection.responseCode in 200..299) {
                    "Phonon-2 download failed (${connection.responseCode})."
                }
                return object : FilterInputStream(connection.inputStream) {
                    override fun close() {
                        try {
                            super.close()
                        } finally {
                            connection.disconnect()
                        }
                    }
                }
            } catch (error: Exception) {
                connection.disconnect()
                throw error
            }
        }
    }
}
