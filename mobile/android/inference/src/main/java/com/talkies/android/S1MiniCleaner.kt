package com.talkies.android

class S1MiniCleaner(private val modelStore: S1MiniModelStore) : TranscriptCleaner {
    override suspend fun clean(transcript: String, options: TranscriptCleanupOptions): String {
        if (transcript.isBlank()) return transcript
        check(modelStore.isInstalled()) { "S1-mini is not installed. Download it before enabling cleanup." }
        val prompt = S1MiniPrompt.render(transcript, options)
        return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
            val output = LocalWhisper.clean(modelStore.modelFile.absolutePath, prompt.encodeToByteArray())
            S1MiniPrompt.resolve(transcript, output.decodeToString())
        }
    }
}
