package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Test

class DictationDestinationResolverTest {
    @Test
    fun recognizesMoshiAndCommonTerminalApps() {
        listOf(
            "app.getmoshi.android",
            "com.termux",
            "org.connectbot",
            "com.sonelli.juicessh",
            "com.server.auditor.ssh.client",
            "org.example.ssh.terminal",
        ).forEach { packageName ->
            assertEquals(packageName, DictationDestination.TERMINAL, DictationDestinationResolver.fromPackageName(packageName))
        }
    }

    @Test
    fun unknownAndOrdinaryAppsStayInGeneralMode() {
        listOf(null, "", "com.google.android.gm", "org.example.terminality.notes").forEach { packageName ->
            assertEquals(packageName, DictationDestination.GENERAL, DictationDestinationResolver.fromPackageName(packageName))
        }
    }

    @Test
    fun matchingIsCaseInsensitiveAndIgnoresWhitespace() {
        assertEquals(DictationDestination.TERMINAL, DictationDestinationResolver.fromPackageName(" APP.GETMOSHI.ANDROID "))
    }

    @Test
    fun terminalDictationSkipsCleanupAndHistoryButOrdinaryDictationKeepsSettings() {
        assertEquals(false, DictationDestination.TERMINAL.allowsCleanup(userEnabled = true))
        assertEquals(false, DictationDestination.TERMINAL.allowsHistory(fieldAllowsHistory = true))
        assertEquals(true, DictationDestination.GENERAL.allowsCleanup(userEnabled = true))
        assertEquals(false, DictationDestination.GENERAL.allowsCleanup(userEnabled = false))
        assertEquals(true, DictationDestination.GENERAL.allowsHistory(fieldAllowsHistory = true))
        assertEquals(false, DictationDestination.GENERAL.allowsHistory(fieldAllowsHistory = false))
    }
}
