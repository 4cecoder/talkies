package com.talkies.android

internal enum class TranscriptStyle(val label: String, val wireValue: String) {
    CASUAL("casual", "casual"),
    SEMI_CASUAL("semi-casual", "semi-casual"),
    BALANCED("balanced", "semi-formal"),
    SEMI_FORMAL("semi-formal", "semi-formal"),
    FORMAL("formal", "formal")
}

internal enum class TranscriptStructure(val wireValue: String) {
    PROSE("prose"),
    LISTS("lists")
}

internal enum class TranscriptContext(val wireValue: String) {
    GENERAL("general"),
    EMAIL("email")
}

internal data class TranscriptCleanupOptions(
    val style: TranscriptStyle = TranscriptStyle.SEMI_FORMAL,
    val structure: TranscriptStructure = TranscriptStructure.PROSE,
    val context: TranscriptContext = TranscriptContext.GENERAL
)

/** Exact Qwen3 chat prefix used by the shared desktop S1-mini cleaners. */
internal object S1MiniPrompt {
    const val SYSTEM = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."

    fun render(transcript: String, options: TranscriptCleanupOptions = TranscriptCleanupOptions()): String {
        val trimmed = transcript.trim(' ', '\t', '\r', '\n')
        return "<|im_start|>system\n$SYSTEM<|im_end|>\n" +
            "<|im_start|>user\n[Styling: ${options.style.wireValue}] " +
            "[Structure: ${options.structure.wireValue}] [Context: ${options.context.wireValue}]\n" +
            "$trimmed<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }

    fun resolve(original: String, modelOutput: String): String {
        val candidate = modelOutput.trim(' ', '\t', '\r', '\n')
        return candidate.ifEmpty { original }
    }
}

internal class S1MiniCleaner(private val modelStore: S1MiniModelStore) {
    suspend fun clean(transcript: String, options: TranscriptCleanupOptions = TranscriptCleanupOptions()): String {
        if (transcript.isBlank()) return transcript
        check(modelStore.isInstalled()) { "S1-mini is not installed. Download it before enabling cleanup." }
        val prompt = S1MiniPrompt.render(transcript, options)
        return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
            val output = LocalWhisper.clean(modelStore.modelFile.absolutePath, prompt.encodeToByteArray())
            S1MiniPrompt.resolve(transcript, output.decodeToString())
        }
    }
}
