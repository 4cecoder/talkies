package com.talkies.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptHistoryTest {
    @Test
    fun schemaMatchesTheSharedCrossPlatformColumns() {
        val columns = Regex("""^\s+(\w+) """, RegexOption.MULTILINE)
            .findAll(TranscriptHistorySchema.CREATE_TABLE).map { it.groupValues[1] }.toList()
        assertEquals(
            listOf("id", "uuid", "created_at", "text", "raw_text", "duration_ms", "runtime", "language"),
            columns
        )
        assertTrue(TranscriptHistorySchema.CREATE_TABLE.contains("uuid TEXT NOT NULL UNIQUE"))
        assertEquals(
            "CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC)",
            TranscriptHistorySchema.CREATE_CREATED_AT_INDEX
        )
        assertEquals("history.sqlite", TranscriptHistorySchema.DATABASE_NAME)
        assertEquals(1, TranscriptHistorySchema.VERSION)
    }

    @Test
    fun rawTextIsNullWhenCleanupDidNotChangeIt() {
        val unchanged = NewTranscript.of("Hello there.", "Hello there.", SpeechEngine.WHISPER_TINY, 1_200L)
        assertNull(unchanged.rawText)
        val cleaned = NewTranscript.of("Hello there.", "um hello there", SpeechEngine.PHONON_2, 1_200L)
        assertEquals("um hello there", cleaned.rawText)
    }

    @Test
    fun recordsRuntimeAndKnownLanguage() {
        val phonon = NewTranscript.of("Hi.", "Hi.", SpeechEngine.PHONON_2, null)
        assertEquals("phonon", phonon.runtime?.wireValue)
        assertEquals("en", phonon.language)
        val whisper = NewTranscript.of("Hi.", "Hi.", SpeechEngine.WHISPER_TINY, null)
        assertEquals("whisper", whisper.runtime?.wireValue)
        assertNull(whisper.language)
        assertEquals(TranscriptRuntime.PHONON, TranscriptRuntime.fromWireValue("phonon"))
        assertNull(TranscriptRuntime.fromWireValue("vendor"))
    }

    @Test
    fun uuidsAreRandomLowercaseVersion4() {
        val pattern = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
        val first = NewTranscript.of("One.", "One.", SpeechEngine.WHISPER_TINY, null).uuid
        val second = NewTranscript.of("One.", "One.", SpeechEngine.WHISPER_TINY, null).uuid
        assertTrue(first, pattern.matches(first))
        assertTrue(second, pattern.matches(second))
        assertFalse(first == second)
    }

    @Test
    fun blankTextIsNotSaved() {
        assertThrowsIllegalArgument { NewTranscript.of("  ", "  ", SpeechEngine.WHISPER_TINY, null) }
    }

    @Test
    fun toStringNeverIncludesTranscriptText() {
        val entry = NewTranscript.of("secret words", "secret words", SpeechEngine.WHISPER_TINY, 10L)
        assertFalse(entry.toString().contains("secret"))
        val record = TranscriptRecord(1, entry.uuid, 2, "secret words", "raw secret", 10, null, null)
        assertFalse(record.toString().contains("secret"))
    }

    @Test
    fun durationIsDerivedFrom16kHzSamples() {
        assertEquals(1_500L, pcmDurationMillis(24_000))
        assertEquals(0L, pcmDurationMillis(0))
    }

    @Test
    fun searchPatternMatchesWildcardsLiterally() {
        assertEquals("%50\\% off\\_now\\\\%", TranscriptHistoryQuery.containsPattern("50% off_now\\"))
    }

    @Test
    fun whereClauseBindsSearchAndCursorAsParameters() {
        assertEquals("" to emptyList<String>(), TranscriptHistoryQuery.where("  ", null))
        val (clause, arguments) = TranscriptHistoryQuery.where(" it's ", TranscriptPageCursor(1_000L, 7L))
        assertEquals(
            "(text LIKE ? ESCAPE '\\' OR raw_text LIKE ? ESCAPE '\\') AND " +
                "(created_at < ? OR (created_at = ? AND id < ?))",
            clause
        )
        assertFalse("search text must be bound, not inlined", clause.contains("it's"))
        assertEquals(listOf("%it's%", "%it's%", "1000", "1000", "7"), arguments)
    }

    @Test
    fun pagesUseTheExtraRowOnlyToDetectMore() {
        val rows = (5L downTo 1L).map { record(id = it, createdAt = it * 10) }
        val first = TranscriptHistoryQuery.toPage(rows.take(3), limit = 2)
        assertEquals(listOf(5L, 4L), first.records.map { it.id })
        assertEquals(TranscriptPageCursor(40L, 4L), first.next)
        val last = TranscriptHistoryQuery.toPage(rows.take(2), limit = 2)
        assertNull(last.next)
    }

    private fun record(id: Long, createdAt: Long) =
        TranscriptRecord(id, newTranscriptUuid(), createdAt, "text $id", null, null, TranscriptRuntime.WHISPER, null)

    private fun assertThrowsIllegalArgument(block: () -> Unit) {
        try {
            block()
        } catch (_: IllegalArgumentException) {
            return
        }
        throw AssertionError("Expected IllegalArgumentException")
    }
}
