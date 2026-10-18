package com.talkies.android

import android.text.InputType
import android.view.inputmethod.EditorInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HistoryTextTest {
    @Test
    fun summaryDescribesEmptySearchAndPagedResults() {
        assertEquals("No saved transcripts yet.", HistoryText.summary(0, hasMore = false, query = ""))
        assertEquals("No saved transcripts match \"cat\".", HistoryText.summary(0, hasMore = false, query = " cat "))
        assertEquals("1 saved transcript.", HistoryText.summary(1, hasMore = false, query = ""))
        assertEquals("Showing the newest 50 transcripts.", HistoryText.summary(50, hasMore = true, query = ""))
    }

    @Test
    fun detailsNameRuntimeDurationAndCleanup() {
        val record = TranscriptRecord(1, "u", 0, "Hello.", "hello", 65_400, TranscriptRuntime.PHONON, "en")
        assertEquals("Today · Phonon-2 · 1m 5s · cleaned", HistoryText.details("Today", record))
        val plain = record.copy(rawText = null, durationMillis = 2_400, runtime = TranscriptRuntime.WHISPER)
        assertEquals("Today · Whisper tiny · 2s", HistoryText.details("Today", plain))
    }

    @Test
    fun keyboardNeverSavesPasswordOrIncognitoFields() {
        val text = InputType.TYPE_CLASS_TEXT
        assertTrue(KeyboardHistoryPolicy.allowsHistory(text, 0))
        assertTrue(KeyboardHistoryPolicy.allowsHistory(text or InputType.TYPE_TEXT_VARIATION_EMAIL_SUBJECT, 0))
        assertFalse(KeyboardHistoryPolicy.allowsHistory(text or InputType.TYPE_TEXT_VARIATION_PASSWORD, 0))
        assertFalse(KeyboardHistoryPolicy.allowsHistory(text or InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD, 0))
        assertFalse(KeyboardHistoryPolicy.allowsHistory(text or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD, 0))
        assertFalse(
            KeyboardHistoryPolicy.allowsHistory(InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD, 0)
        )
        assertFalse(KeyboardHistoryPolicy.allowsHistory(text, EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING))
    }
}
