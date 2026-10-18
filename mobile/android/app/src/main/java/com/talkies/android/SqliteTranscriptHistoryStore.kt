package com.talkies.android

import android.content.ContentValues
import android.content.Context
import android.content.SharedPreferences
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.text.InputType
import android.view.inputmethod.EditorInfo

/**
 * Transcript history in the app's private databases directory, using the shared cross-platform
 * schema. One instance per process: the app screen and the keyboard share it through [TranscriptHistory].
 * Never log transcript text from this class.
 */
internal class SqliteTranscriptHistoryStore(
    context: Context,
    databaseName: String = TranscriptHistorySchema.DATABASE_NAME,
) : SQLiteOpenHelper(context.applicationContext, databaseName, null, TranscriptHistorySchema.VERSION),
    TranscriptHistoryStore {

    init {
        setWriteAheadLoggingEnabled(true)
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        // Overwrite deleted rows instead of leaving their text in free pages.
        db.rawQuery("PRAGMA secure_delete = ON", null).use { it.moveToFirst() }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(TranscriptHistorySchema.CREATE_TABLE)
        db.execSQL(TranscriptHistorySchema.CREATE_CREATED_AT_INDEX)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Version 1 is the only schema so far.
    }

    override fun insert(transcript: NewTranscript): TranscriptRecord {
        val values = ContentValues().apply {
            put("uuid", transcript.uuid)
            put("created_at", transcript.createdAtMillis)
            put("text", transcript.text)
            put("raw_text", transcript.rawText)
            put("duration_ms", transcript.durationMillis)
            put("runtime", transcript.runtime?.wireValue)
            put("language", transcript.language)
        }
        val id = writableDatabase.insertOrThrow(TABLE, null, values)
        return TranscriptRecord(
            id = id,
            uuid = transcript.uuid,
            createdAtMillis = transcript.createdAtMillis,
            text = transcript.text,
            rawText = transcript.rawText,
            durationMillis = transcript.durationMillis,
            runtime = transcript.runtime,
            language = transcript.language,
        )
    }

    override fun page(query: String?, after: TranscriptPageCursor?, limit: Int): TranscriptPage {
        require(limit > 0) { "Page size must be positive." }
        val (where, arguments) = TranscriptHistoryQuery.where(query, after)
        val sql = buildString {
            append("SELECT id, uuid, created_at, text, raw_text, duration_ms, runtime, language FROM ")
            append(TABLE)
            if (where.isNotEmpty()) append(" WHERE ").append(where)
            append(" ORDER BY ").append(TranscriptHistoryQuery.ORDER_BY)
            append(" LIMIT ").append(limit + 1)
        }
        val rows = readableDatabase.rawQuery(sql, arguments.toTypedArray()).use { cursor ->
            buildList { while (cursor.moveToNext()) add(cursor.toRecord()) }
        }
        return TranscriptHistoryQuery.toPage(rows, limit)
    }

    override fun delete(id: Long): Boolean =
        writableDatabase.delete(TABLE, "id = ?", arrayOf(id.toString())) > 0

    override fun clear() {
        val db = writableDatabase
        db.execSQL("DELETE FROM $TABLE")
        // VACUUM cannot run inside a transaction; it rewrites the file without the deleted pages.
        db.execSQL("VACUUM")
        db.rawQuery("PRAGMA wal_checkpoint(TRUNCATE)", null).use { it.moveToFirst() }
    }

    private fun Cursor.toRecord() = TranscriptRecord(
        id = getLong(0),
        uuid = getString(1),
        createdAtMillis = getLong(2),
        text = getString(3),
        rawText = if (isNull(4)) null else getString(4),
        durationMillis = if (isNull(5)) null else getLong(5),
        runtime = TranscriptRuntime.fromWireValue(if (isNull(6)) null else getString(6)),
        language = if (isNull(7)) null else getString(7),
    )

    private companion object {
        const val TABLE = "transcripts"
    }
}

/** Process-wide history store and the "Save transcript history" setting. */
internal object TranscriptHistory {
    private const val ENABLED_KEY = "history-enabled"

    @Volatile private var instance: TranscriptHistoryStore? = null

    fun store(context: Context): TranscriptHistoryStore =
        instance ?: synchronized(this) {
            instance ?: SqliteTranscriptHistoryStore(context).also { instance = it }
        }

    /** On by default. Turning it off stops saving; it does not delete saved transcripts. */
    fun isEnabled(preferences: SharedPreferences): Boolean = preferences.getBoolean(ENABLED_KEY, true)

    fun setEnabled(preferences: SharedPreferences, enabled: Boolean) {
        preferences.edit().putBoolean(ENABLED_KEY, enabled).apply()
    }

    /**
     * Saves one finished dictation when history is on. Blocking; call off the main thread. A storage
     * failure must not break dictation, so it is reported as false without logging any text.
     */
    fun saveIfEnabled(context: Context, preferences: SharedPreferences, transcript: NewTranscript): Boolean {
        if (!isEnabled(preferences)) return false
        return runCatching { store(context).insert(transcript) }.isSuccess
    }
}

/** Whether keyboard dictation into a field may be saved. Password and incognito fields never are. */
internal object KeyboardHistoryPolicy {
    fun allowsHistory(inputType: Int, imeOptions: Int): Boolean {
        if (imeOptions and EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING != 0) return false
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return when (inputType and InputType.TYPE_MASK_CLASS) {
            InputType.TYPE_CLASS_TEXT -> variation != InputType.TYPE_TEXT_VARIATION_PASSWORD &&
                variation != InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD &&
                variation != InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
            InputType.TYPE_CLASS_NUMBER -> variation != InputType.TYPE_NUMBER_VARIATION_PASSWORD
            else -> true
        }
    }
}
