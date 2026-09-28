package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class S1MiniPromptTest {
    @Test
    fun renderMatchesSharedQwenChatFormat() {
        val prompt = S1MiniPrompt.render("  send the email tomorrow  ")

        assertEquals(
            "<|im_start|>system\n${S1MiniPrompt.SYSTEM}<|im_end|>\n" +
                "<|im_start|>user\n[Styling: semi-formal] [Structure: prose] [Context: general]\n" +
                "send the email tomorrow<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
            prompt
        )
    }

    @Test
    fun renderUsesAllRequestedCleanupOptions() {
        val prompt = S1MiniPrompt.render(
            "make this a list",
            TranscriptCleanupOptions(
                style = TranscriptStyle.CASUAL,
                structure = TranscriptStructure.LISTS,
                context = TranscriptContext.EMAIL
            )
        )

        assertTrue(prompt.contains("[Styling: casual] [Structure: lists] [Context: email]"))
    }

    @Test
    fun balancedToneUsesTheModelsSupportedSemiFormalControl() {
        val prompt = S1MiniPrompt.render(
            "clean this",
            TranscriptCleanupOptions(style = TranscriptStyle.BALANCED)
        )

        assertTrue(prompt.contains("[Styling: semi-formal] [Structure: prose] [Context: general]"))
    }

    @Test
    fun blankModelOutputKeepsTheRawTranscript() {
        assertEquals("raw ASR", S1MiniPrompt.resolve("raw ASR", " \n\t "))
        assertEquals("cleaned text", S1MiniPrompt.resolve("raw ASR", "  cleaned text \n"))
    }
}
