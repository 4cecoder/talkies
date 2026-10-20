package com.talkies.android

/** Prepares local dictation for a remote prompt without ever adding a submit key. */
object TerminalInputPolicy {
    fun stage(text: String): String = text.replace(Regex("[\\r\\n]+"), " ").trim()
}
