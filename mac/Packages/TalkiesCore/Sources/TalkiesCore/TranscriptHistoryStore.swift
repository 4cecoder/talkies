import Foundation
import SQLite3

/// One saved dictation. Mirrors a row of the shared cross-platform `transcripts` table.
public struct TranscriptRecord: Identifiable, Equatable, Sendable {
    /// Local row id. Not stable across devices; use `uuid` to identify a transcript elsewhere.
    public let id: Int64
    /// Random lowercase UUIDv4 assigned on insert.
    public let uuid: String
    public let createdAt: Date
    /// Final text that was inserted (after cleanup).
    public let text: String
    /// Recognizer output before cleanup; nil when identical to `text`.
    public let rawText: String?
    public let durationMs: Int64?
    /// Runtime identifier as stored ('phonon' | 'whisper'). Kept as a string so rows written by
    /// another client with a runtime this build does not know still load.
    public let runtime: String?
    public let language: String?

    public var runtimeID: SpeechRuntimeID? { runtime.flatMap(SpeechRuntimeID.init(rawValue:)) }
}

/// Fields supplied when saving a dictation.
public struct NewTranscript: Sendable {
    public var createdAt: Date
    public var text: String
    public var rawText: String?
    public var durationMs: Int64?
    public var runtime: SpeechRuntimeID?
    public var language: String?

    public init(
        createdAt: Date = Date(),
        text: String,
        rawText: String? = nil,
        durationMs: Int64? = nil,
        runtime: SpeechRuntimeID? = nil,
        language: String? = nil
    ) {
        self.createdAt = createdAt
        self.text = text
        self.rawText = rawText
        self.durationMs = durationMs
        self.runtime = runtime
        self.language = language
    }
}

public enum TranscriptHistoryError: Error, Equatable, LocalizedError {
    case open(String)
    case sqlite(String)
    /// The file was written by a newer Talkies with a schema this build does not understand.
    case unsupportedSchemaVersion(Int32)

    public var errorDescription: String? {
        switch self {
        case .open(let message): "Could not open transcript history: \(message)"
        case .sqlite(let message): "Transcript history error: \(message)"
        case .unsupportedSchemaVersion(let version):
            "Transcript history was created by a newer Talkies (schema \(version))."
        }
    }
}

/// Local SQLite transcript history. The connection is opened lazily on the actor's executor,
/// so neither opening nor querying runs on the main thread. Errors carry SQLite messages only,
/// never transcript text.
public actor TranscriptHistoryStore {
    public static let schemaVersion: Int32 = 1

    public let fileURL: URL
    /// Only touched on the actor's executor, plus once in `deinit` when no other reference exists.
    nonisolated(unsafe) private var db: OpaquePointer?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/Talkies/history.sqlite`
    public static func defaultFileURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Talkies/history.sqlite", isDirectory: false)
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - Public API

    /// Inserts a transcript. `rawText` is stored as NULL when it equals `text`.
    @discardableResult
    public func insert(_ transcript: NewTranscript) throws -> TranscriptRecord {
        let db = try connection()
        let uuid = UUID().uuidString.lowercased()
        let createdAtMs = Self.milliseconds(transcript.createdAt)
        let rawText = transcript.rawText == transcript.text ? nil : transcript.rawText
        try execute(
            db,
            """
            INSERT INTO transcripts (uuid, created_at, text, raw_text, duration_ms, runtime, language)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(uuid), .int(createdAtMs), .text(transcript.text), rawText.map(SQLValue.text) ?? .null,
                transcript.durationMs.map(SQLValue.int) ?? .null,
                transcript.runtime.map { .text($0.rawValue) } ?? .null,
                transcript.language.map(SQLValue.text) ?? .null,
            ]
        )
        return TranscriptRecord(
            id: sqlite3_last_insert_rowid(db),
            uuid: uuid,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtMs) / 1_000),
            text: transcript.text,
            rawText: rawText,
            durationMs: transcript.durationMs,
            runtime: transcript.runtime?.rawValue,
            language: transcript.language
        )
    }

    /// Returns one page of transcripts, newest first. Pass the last record of the previous page as
    /// `after` to continue (keyset paging, so deletes between pages do not skip rows). `search`
    /// matches `text` with a parameterized LIKE; SQLite's LIKE folds ASCII case only.
    public func fetch(search: String? = nil, limit: Int = 50, after: TranscriptRecord? = nil) throws -> [TranscriptRecord] {
        let db = try connection()
        var clauses: [String] = []
        var bindings: [SQLValue] = []
        if let search = search?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
            clauses.append("text LIKE ? ESCAPE '\\'")
            bindings.append(.text("%" + Self.escapeLike(search) + "%"))
        }
        if let after {
            clauses.append("(created_at < ? OR (created_at = ? AND id < ?))")
            let ms = Self.milliseconds(after.createdAt)
            bindings += [.int(ms), .int(ms), .int(after.id)]
        }
        let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        bindings.append(.int(Int64(max(0, limit))))
        let sql = """
        SELECT id, uuid, created_at, text, raw_text, duration_ms, runtime, language
        FROM transcripts \(whereClause)
        ORDER BY created_at DESC, id DESC
        LIMIT ?
        """
        return try query(db, sql, bindings: bindings) { statement in
            TranscriptRecord(
                id: sqlite3_column_int64(statement, 0),
                uuid: Self.columnText(statement, 1) ?? "",
                createdAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)) / 1_000),
                text: Self.columnText(statement, 3) ?? "",
                rawText: Self.columnText(statement, 4),
                durationMs: sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 5),
                runtime: Self.columnText(statement, 6),
                language: Self.columnText(statement, 7)
            )
        }
    }

    public func count() throws -> Int {
        let db = try connection()
        return try query(db, "SELECT COUNT(*) FROM transcripts") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    public func delete(id: Int64) throws {
        let db = try connection()
        try execute(db, "DELETE FROM transcripts WHERE id = ?", bindings: [.int(id)])
    }

    /// Deletes every transcript, then compacts the file and truncates the WAL so deleted text does
    /// not linger on disk.
    public func clearAll() throws {
        let db = try connection()
        try execute(db, "DELETE FROM transcripts")
        try execute(db, "VACUUM")
        try execute(db, "PRAGMA wal_checkpoint(TRUNCATE)")
    }

    /// Closes the connection. The next call reopens it.
    public func close() {
        if let db { sqlite3_close_v2(db) }
        db = nil
    }

    // MARK: - Connection and migrations

    private func connection() throws -> OpaquePointer {
        if let db { return db }
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            } catch {
                throw TranscriptHistoryError.open("could not create the history directory")
            }
        }
        // Create the file owner-only before SQLite opens it; SQLite gives -wal/-shm the same mode.
        if !fileManager.fileExists(atPath: fileURL.path) {
            guard fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
                throw TranscriptHistoryError.open("could not create the history file")
            }
        }

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(fileURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "out of memory"
            if let handle { sqlite3_close_v2(handle) }
            throw TranscriptHistoryError.open(message)
        }
        do {
            try Self.restrictPermissions(of: fileURL)
            sqlite3_busy_timeout(handle, 2_000)
            try execute(handle, "PRAGMA journal_mode = WAL")
            try execute(handle, "PRAGMA secure_delete = ON")
            try migrate(handle)
            try Self.restrictPermissions(of: fileURL)
        } catch {
            sqlite3_close_v2(handle)
            throw error
        }
        db = handle
        return handle
    }

    private func migrate(_ db: OpaquePointer) throws {
        let version = try query(db, "PRAGMA user_version") { sqlite3_column_int($0, 0) }.first ?? 0
        guard version <= Self.schemaVersion else { throw TranscriptHistoryError.unsupportedSchemaVersion(version) }
        guard version < Self.schemaVersion else { return }

        try execute(db, "BEGIN IMMEDIATE")
        do {
            if version < 1 {
                try execute(db, """
                CREATE TABLE IF NOT EXISTS transcripts (
                  id INTEGER PRIMARY KEY,
                  uuid TEXT NOT NULL UNIQUE,
                  created_at INTEGER NOT NULL,
                  text TEXT NOT NULL,
                  raw_text TEXT,
                  duration_ms INTEGER,
                  runtime TEXT,
                  language TEXT
                )
                """)
                try execute(db, "CREATE INDEX IF NOT EXISTS transcripts_created_at ON transcripts(created_at DESC)")
            }
            try execute(db, "PRAGMA user_version = \(Self.schemaVersion)")
            try execute(db, "COMMIT")
        } catch {
            try? execute(db, "ROLLBACK")
            throw error
        }
    }

    private static func restrictPermissions(of url: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { continue }
            guard chmod(path, 0o600) == 0 else {
                throw TranscriptHistoryError.open("could not restrict history file permissions")
            }
        }
    }

    // MARK: - SQLite helpers

    private enum SQLValue {
        case null
        case int(Int64)
        case text(String)
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func prepare(_ db: OpaquePointer, _ sql: String, bindings: [SQLValue]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TranscriptHistoryError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .null: result = sqlite3_bind_null(statement, index)
            case .int(let number): result = sqlite3_bind_int64(statement, index, number)
            case .text(let string): result = sqlite3_bind_text(statement, index, string, -1, Self.transient)
            }
            guard result == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw TranscriptHistoryError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
        }
        return statement
    }

    private func execute(_ db: OpaquePointer, _ sql: String, bindings: [SQLValue] = []) throws {
        let statement = try prepare(db, sql, bindings: bindings)
        defer { sqlite3_finalize(statement) }
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW { result = sqlite3_step(statement) }
        guard result == SQLITE_DONE else {
            throw TranscriptHistoryError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(
        _ db: OpaquePointer,
        _ sql: String,
        bindings: [SQLValue] = [],
        row: (OpaquePointer) -> T
    ) throws -> [T] {
        let statement = try prepare(db, sql, bindings: bindings)
        defer { sqlite3_finalize(statement) }
        var rows: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                rows.append(row(statement))
            } else if result == SQLITE_DONE {
                return rows
            } else {
                throw TranscriptHistoryError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private static func columnText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    static func escapeLike(_ value: String) -> String {
        var escaped = ""
        for character in value {
            if character == "\\" || character == "%" || character == "_" { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }
}
