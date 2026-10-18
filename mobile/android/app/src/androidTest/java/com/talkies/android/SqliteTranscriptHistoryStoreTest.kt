package com.talkies.android

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Runs against the device's real SQLite in a throwaway database, never the user's history.sqlite. */
@RunWith(AndroidJUnit4::class)
class SqliteTranscriptHistoryStoreTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var store: SqliteTranscriptHistoryStore

    @Before
    fun open() {
        context.deleteDatabase(DATABASE)
        store = SqliteTranscriptHistoryStore(context, DATABASE)
    }

    @After
    fun close() {
        store.close()
        context.deleteDatabase(DATABASE)
    }

    @Test
    fun opensInWalModeWithTheSharedSchema() {
        val db = store.readableDatabase
        db.rawQuery("PRAGMA journal_mode", null).use {
            assertTrue(it.moveToFirst())
            assertEquals("wal", it.getString(0).lowercase())
        }
        val columns = db.rawQuery("PRAGMA table_info(transcripts)", null).use { cursor ->
            buildList { while (cursor.moveToNext()) add(cursor.getString(1)) }
        }
        assertEquals(listOf("id", "uuid", "created_at", "text", "raw_text", "duration_ms", "runtime", "language"), columns)
        assertEquals(1, db.version)
        assertTrue(context.getDatabasePath(DATABASE).parentFile!!.path.startsWith(context.dataDir.path))
    }

    @Test
    fun pagesNewestFirstAndRoundTripsColumns() {
        for (index in 1..5) {
            store.insert(entry("note $index", createdAt = index * 1_000L))
        }
        val saved = store.insert(
            NewTranscript.of("Cleaned.", "um cleaned", SpeechEngine.PHONON_2, 2_000L, createdAtMillis = 9_000L)
        )
        val first = store.page(null, null, limit = 4)
        assertEquals(listOf("Cleaned.", "note 5", "note 4", "note 3"), first.records.map { it.text })
        val newest = first.records.first()
        assertEquals(saved, newest)
        assertEquals("um cleaned", newest.rawText)
        assertEquals(TranscriptRuntime.PHONON, newest.runtime)
        assertEquals("en", newest.language)
        val second = store.page(null, first.next, limit = 4)
        assertEquals(listOf("note 2", "note 1"), second.records.map { it.text })
        assertNull(second.next)
    }

    @Test
    fun searchIsParameterizedAndMatchesWildcardsLiterally() {
        store.insert(entry("50% off today"))
        store.insert(entry("500 off today"))
        store.insert(entry("Robert'); DROP TABLE transcripts;--"))
        assertEquals(listOf("50% off today"), store.page("50%", null, 10).records.map { it.text })
        assertEquals(1, store.page("'); DROP TABLE", null, 10).records.size)
        assertEquals(3, store.page("", null, 10).records.size)
    }

    @Test
    fun deleteOneAndClearAll() {
        val keep = store.insert(entry("keep"))
        val remove = store.insert(entry("remove"))
        assertTrue(store.delete(remove.id))
        assertFalse(store.delete(remove.id))
        assertEquals(listOf(keep.id), store.page(null, null, 10).records.map { it.id })
        store.clear()
        assertTrue(store.page(null, null, 10).records.isEmpty())
        store.insert(entry("after clear"))
        assertEquals(1, store.page(null, null, 10).records.size)
    }

    private fun entry(text: String, createdAt: Long = System.currentTimeMillis()) =
        NewTranscript.of(text, text, SpeechEngine.WHISPER_TINY, 1_000L, createdAtMillis = createdAt)

    private companion object {
        const val DATABASE = "history-test.sqlite"
    }
}
