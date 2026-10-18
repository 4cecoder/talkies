package com.talkies.android

import java.util.Locale
import java.util.UUID

/**
 * The cross-platform transcript-history schema. Every client stores the same table so history can be
 * exchanged later; change it only together with the other platforms.
 */
object TranscriptHistorySchema {
    const val DATABASE_NAME = "history.sqlite"
    const val VERSION = 1

    const val CREATE_TABLE = """CREATE TABLE IF NOT EXISTS transcripts (
  id INTEGER PRIMARY KEY,
  uuid TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL,
  text TEXT NOT NULL,
  raw_text TEXT,
  duration_ms INTEGER,
  runtime TEXT,
  language TEXT
)"""

    const val CREATE_CREATED_AT_INDEX =
        "CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC)"
}

/** Values stored in the `runtime` column. */
enum class TranscriptRuntime(val wireValue: String) {
    PHONON("phonon"),
    WHISPER("whisper"),
    ;

    companion object {
        fun of(engine: SpeechEngine): TranscriptRuntime = when (engine) {
            SpeechEngine.PHONON_2 -> PHONON
            SpeechEngine.WHISPER_TINY -> WHISPER
        }

        fun fromWireValue(value: String?): TranscriptRuntime? = entries.firstOrNull { it.wireValue == value }
    }
}

/** One saved dictation. [rawText] is null when cleanup did not change the recognizer output. */
data class TranscriptRecord(
    val id: Long,
    val uuid: String,
    val createdAtMillis: Long,
    val text: String,
    val rawText: String?,
    val durationMillis: Long?,
    val runtime: TranscriptRuntime?,
    val language: String?,
) {
    // Transcript text never appears in logs or crash reports through toString().
    override fun toString(): String = "TranscriptRecord(id=$id, uuid=$uuid, createdAtMillis=$createdAtMillis)"
}

/** A dictation to save. Build it with [NewTranscript.of] so the column rules are applied. */
data class NewTranscript(
    val uuid: String,
    val createdAtMillis: Long,
    val text: String,
    val rawText: String?,
    val durationMillis: Long?,
    val runtime: TranscriptRuntime?,
    val language: String?,
) {
    init {
        require(text.isNotBlank()) { "A saved transcript needs text." }
        require(durationMillis == null || durationMillis >= 0) { "Duration cannot be negative." }
    }

    override fun toString(): String = "NewTranscript(uuid=$uuid, createdAtMillis=$createdAtMillis)"

    companion object {
        /**
         * [text] is the final inserted text; [rawText] the recognizer output before cleanup. Phonon-2
         * is English only; Whisper's detected language is not reported, so it is stored as unknown.
         */
        fun of(
            text: String,
            rawText: String,
            engine: SpeechEngine,
            durationMillis: Long?,
            createdAtMillis: Long = System.currentTimeMillis(),
            uuid: String = newTranscriptUuid(),
        ): NewTranscript = NewTranscript(
            uuid = uuid,
            createdAtMillis = createdAtMillis,
            text = text,
            rawText = rawText.takeIf { it != text },
            durationMillis = durationMillis,
            runtime = TranscriptRuntime.of(engine),
            language = if (engine == SpeechEngine.PHONON_2) "en" else null,
        )
    }
}

/** A random lowercase UUIDv4. */
fun newTranscriptUuid(): String = UUID.randomUUID().toString().lowercase(Locale.ROOT)

/** Length of 16 kHz mono audio, the format every Talkies recognizer receives. */
fun pcmDurationMillis(sampleCount: Int, sampleRate: Int = 16_000): Long {
    require(sampleCount >= 0 && sampleRate > 0) { "Invalid audio length." }
    return sampleCount * 1000L / sampleRate
}

/** Keyset position for the next page: rows strictly older than this one. */
data class TranscriptPageCursor(val createdAtMillis: Long, val id: Long)

data class TranscriptPage(val records: List<TranscriptRecord>, val next: TranscriptPageCursor?)

/**
 * Local transcript history. Implementations do blocking I/O; call every method off the main thread.
 * A future sync layer composes this interface rather than replacing the local store.
 */
interface TranscriptHistoryStore {
    fun insert(transcript: NewTranscript): TranscriptRecord

    /** Newest first. A blank [query] matches every row; otherwise `text` or `raw_text` contains it. */
    fun page(query: String?, after: TranscriptPageCursor?, limit: Int): TranscriptPage

    fun delete(id: Long): Boolean

    /** Deletes every row and compacts storage so deleted text is not left in the database file. */
    fun clear()
}

/** SQL fragments shared by the SQLite stores; values are always bound as parameters. */
object TranscriptHistoryQuery {
    const val LIKE_ESCAPE = '\\'

    /** A `LIKE ... ESCAPE '\'` pattern that matches [query] literally anywhere in the column. */
    fun containsPattern(query: String): String = buildString {
        append('%')
        for (character in query) {
            if (character == '%' || character == '_' || character == LIKE_ESCAPE) append(LIKE_ESCAPE)
            append(character)
        }
        append('%')
    }

    /** The WHERE clause and its arguments, in order, for a page request. Empty clause means no filter. */
    fun where(query: String?, after: TranscriptPageCursor?): Pair<String, List<String>> {
        val clauses = mutableListOf<String>()
        val arguments = mutableListOf<String>()
        val trimmed = query?.trim().orEmpty()
        if (trimmed.isNotEmpty()) {
            val pattern = containsPattern(trimmed)
            clauses += "(text LIKE ? ESCAPE '\\' OR raw_text LIKE ? ESCAPE '\\')"
            arguments += listOf(pattern, pattern)
        }
        if (after != null) {
            clauses += "(created_at < ? OR (created_at = ? AND id < ?))"
            arguments += listOf(after.createdAtMillis.toString(), after.createdAtMillis.toString(), after.id.toString())
        }
        return clauses.joinToString(" AND ") to arguments
    }

    const val ORDER_BY = "created_at DESC, id DESC"

    /** Builds a page from up to `limit + 1` rows; the extra row only signals that more exist. */
    fun toPage(rows: List<TranscriptRecord>, limit: Int): TranscriptPage {
        require(limit > 0) { "Page size must be positive." }
        val records = rows.take(limit)
        val next = if (rows.size > limit) records.last().let { TranscriptPageCursor(it.createdAtMillis, it.id) } else null
        return TranscriptPage(records, next)
    }
}
