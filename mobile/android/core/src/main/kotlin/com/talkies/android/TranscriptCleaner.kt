package com.talkies.android

/** Cleans a raw transcript using the user's local formatting preferences. */
interface TranscriptCleaner {
    suspend fun clean(
        transcript: String,
        options: TranscriptCleanupOptions = TranscriptCleanupOptions()
    ): String
}
