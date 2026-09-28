package com.talkies.android

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class S1MiniCleaner(private val modelStore: S1MiniModelStore) : TranscriptCleaner {
    override suspend fun clean(transcript: String, options: TranscriptCleanupOptions): String {
        if (transcript.isBlank()) return transcript
        val modelInstalled = withContext(Dispatchers.IO) { modelStore.isInstalled() }
        check(modelInstalled) { "S1-mini is not installed. Download it before enabling cleanup." }
        val prompt = S1MiniPrompt.render(transcript, options)
        return withContext(Dispatchers.Default) {
            val output = LocalWhisper.clean(modelStore.modelFile.absolutePath, prompt.encodeToByteArray())
            S1MiniPrompt.resolve(transcript, output.decodeToString())
        }
    }
}
