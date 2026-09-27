package com.talkies.android

internal fun appendTranscript(existing: String, recognized: String): String =
    listOf(existing.trim(), recognized.trim()).filter(String::isNotBlank).joinToString(" ")
