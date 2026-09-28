package com.talkies.android

internal fun appendTranscript(existing: String, recognized: String): String =
    listOf(existing.trim(), recognized.trim()).filter(String::isNotBlank).joinToString(" ")

internal fun appendDictationSpacing(beforeCursor: String, dictatedText: String): String =
    if (beforeCursor.isEmpty() || beforeCursor.last().isWhitespace() || dictatedText.firstOrNull()?.isWhitespace() == true) {
        dictatedText
    } else {
        " $dictatedText"
    }
