package com.talkies.android

/** The kind of editor currently receiving Talkies dictation. */
enum class DictationDestination {
    GENERAL,
    TERMINAL;

    /** Cleanup can slow dictation and may alter agent instructions or code identifiers. */
    fun allowsCleanup(userEnabled: Boolean): Boolean = this == GENERAL && userEnabled

    /** Agent prompts can contain project details, so terminal text is not stored in history. */
    fun allowsHistory(fieldAllowsHistory: Boolean): Boolean = this == GENERAL && fieldAllowsHistory
}

/** Identifies common terminal/SSH editors without inspecting their content or sending it remotely. */
object DictationDestinationResolver {
    private val knownTerminalPackages = setOf(
        "app.getmoshi.android",
        "com.sonelli.juicessh",
        "com.termux",
        "org.connectbot",
        "com.server.auditor.ssh.client",
    )

    fun fromPackageName(packageName: String?): DictationDestination {
        val normalized = packageName?.trim()?.lowercase().orEmpty()
        if (normalized.isEmpty()) return DictationDestination.GENERAL
        if (normalized in knownTerminalPackages) return DictationDestination.TERMINAL

        val components = normalized.split('.')
        val terminalMarkers = setOf("terminal", "ssh", "sshclient", "shell", "mosh")
        return if (components.any { it in terminalMarkers }) {
            DictationDestination.TERMINAL
        } else {
            DictationDestination.GENERAL
        }
    }
}
