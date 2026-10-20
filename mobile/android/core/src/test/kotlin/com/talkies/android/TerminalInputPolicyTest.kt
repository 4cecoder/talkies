package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Test

class TerminalInputPolicyTest {
    @Test
    fun normalizesSpeechLinesWithoutAddingAnEnterKey() {
        assertEquals("fix the parser and run tests", TerminalInputPolicy.stage("  fix the parser\n\nand run tests  "))
        assertEquals("", TerminalInputPolicy.stage("\r\n  "))
    }
}
