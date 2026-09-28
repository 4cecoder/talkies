package com.talkies.android

fun appendTranscript(existing: String, recognized: String): String =
    listOf(existing.trim(), recognized.trim()).filter(String::isNotBlank).joinToString(" ")

fun appendDictationSpacing(
    beforeCursor: String,
    dictatedText: String,
    afterCursor: String = ""
): String {
    val needsLeadingSpace = beforeCursor.isNotEmpty() && !beforeCursor.last().isWhitespace() &&
        dictatedText.firstOrNull()?.isWhitespace() != true
    val needsTrailingSpace = dictatedText.lastOrNull()?.isLetterOrDigit() == true &&
        afterCursor.firstOrNull()?.isLetterOrDigit() == true
    return buildString {
        if (needsLeadingSpace) append(' ')
        append(dictatedText)
        if (needsTrailingSpace) append(' ')
    }
}
