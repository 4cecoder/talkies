import Foundation
import SQLite3
import XCTest
@testable import TalkiesCore

final class TranscriptHistoryStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("Talkies/history.sqlite") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TalkiesHistoryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMigrationCreatesSharedSchemaAndSetsUserVersion() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let initialCount = try await store.count()
        XCTAssertEqual(initialCount, 0)
        await store.close()

        let db = try openRaw()
        defer { sqlite3_close_v2(db) }
        XCTAssertEqual(try scalarInt(db, "PRAGMA user_version"), 1)
        XCTAssertEqual(try scalarText(db, "PRAGMA journal_mode"), "wal")
        XCTAssertEqual(
            try column(db, "SELECT name FROM pragma_table_info('transcripts') ORDER BY cid"),
            ["id", "uuid", "created_at", "text", "raw_text", "duration_ms", "runtime", "language"]
        )
        XCTAssertEqual(
            try column(db, "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'transcripts' AND sql IS NOT NULL"),
            ["transcripts_created_at"]
        )

        // Reopening an up-to-date file is a no-op.
        let reopened = TranscriptHistoryStore(fileURL: fileURL)
        let reopenedCount = try await reopened.count()
        XCTAssertEqual(reopenedCount, 0)
    }

    func testRefusesNewerSchemaVersion() async throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let db = try openRaw()
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA user_version = 99", nil, nil, nil), SQLITE_OK)
        sqlite3_close_v2(db)

        let store = TranscriptHistoryStore(fileURL: fileURL)
        do {
            _ = try await store.count()
            XCTFail("Expected unsupported schema error")
        } catch let error as TranscriptHistoryError {
            XCTAssertEqual(error, .unsupportedSchemaVersion(99))
        }
    }

    func testInsertStoresFieldsAndCollapsesIdenticalRawText() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let date = Date(timeIntervalSince1970: 1_700_000_000.123)
        let cleaned = try await store.insert(NewTranscript(
            createdAt: date, text: "Hello, world.", rawText: "hello world", durationMs: 1_500, runtime: .phonon, language: "en"
        ))
        let identical = try await store.insert(NewTranscript(createdAt: date.addingTimeInterval(1), text: "same", rawText: "same", runtime: .whisper))

        XCTAssertNil(identical.rawText)
        XCTAssertNotEqual(cleaned.uuid, identical.uuid)
        let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"#
        XCTAssertNotNil(cleaned.uuid.range(of: uuidPattern, options: .regularExpression))

        let rows = try await store.fetch()
        XCTAssertEqual(rows, [identical, cleaned])
        XCTAssertEqual(rows[1].rawText, "hello world")
        XCTAssertEqual(rows[1].durationMs, 1_500)
        XCTAssertEqual(rows[1].runtimeID, .phonon)
        XCTAssertEqual(rows[1].language, "en")
        XCTAssertNil(rows[0].language)
        XCTAssertNil(rows[0].durationMs)

        await store.close()
        let db = try openRaw()
        defer { sqlite3_close_v2(db) }
        XCTAssertEqual(try scalarInt(db, "SELECT created_at FROM transcripts WHERE id = \(cleaned.id)"), 1_700_000_000_123)
        XCTAssertEqual(try scalarInt(db, "SELECT COUNT(*) FROM transcripts WHERE raw_text IS NULL"), 1)
        XCTAssertEqual(try scalarText(db, "SELECT runtime FROM transcripts WHERE id = \(identical.id)"), "whisper")
    }

    func testFetchOrdersNewestFirstAndPagesWithoutSkipping() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Two rows share a timestamp to exercise the id tiebreak.
        let offsets: [TimeInterval] = [0, 10, 10, 20, 30]
        for (index, offset) in offsets.enumerated() {
            try await store.insert(NewTranscript(createdAt: base.addingTimeInterval(offset), text: "entry \(index)"))
        }

        let first = try await store.fetch(limit: 2)
        XCTAssertEqual(first.map(\.text), ["entry 4", "entry 3"])
        // A delete between pages must not shift the next page.
        try await store.delete(id: first[0].id)
        let second = try await store.fetch(limit: 2, after: first.last)
        XCTAssertEqual(second.map(\.text), ["entry 2", "entry 1"])
        let third = try await store.fetch(limit: 2, after: second.last)
        XCTAssertEqual(third.map(\.text), ["entry 0"])
    }

    func testSearchIsCaseInsensitiveAndTreatsWildcardsLiterally() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        try await store.insert(NewTranscript(text: "Meet Alice at noon"))
        try await store.insert(NewTranscript(text: "Budget is 100% approved"))
        try await store.insert(NewTranscript(text: "file_name.txt"))
        try await store.insert(NewTranscript(text: "filename"))
        try await store.insert(NewTranscript(text: "nothing here'); DROP TABLE transcripts; --"))

        let alice = try await store.fetch(search: "ALICE")
        XCTAssertEqual(alice.map(\.text), ["Meet Alice at noon"])
        let percent = try await store.fetch(search: "100%")
        XCTAssertEqual(percent.map(\.text), ["Budget is 100% approved"])
        let underscore = try await store.fetch(search: "file_")
        XCTAssertEqual(underscore.map(\.text), ["file_name.txt"])
        let quoted = try await store.fetch(search: "'); DROP")
        XCTAssertEqual(quoted.count, 1)
        let blank = try await store.fetch(search: "   ")
        XCTAssertEqual(blank.count, 5)
        let missing = try await store.fetch(search: "missing")
        XCTAssertEqual(missing.count, 0)
        let total = try await store.count()
        XCTAssertEqual(total, 5)
    }

    func testDeleteRemovesOnlyThatEntry() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let keep = try await store.insert(NewTranscript(text: "keep"))
        let remove = try await store.insert(NewTranscript(text: "remove"))

        try await store.delete(id: remove.id)

        let remaining = try await store.fetch()
        XCTAssertEqual(remaining, [keep])
    }

    func testClearAllRemovesEverythingAndCompactsFile() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        let secret = "unique-secret-phrase-\(UUID().uuidString)"
        for index in 0..<200 {
            try await store.insert(NewTranscript(text: "\(secret) \(index) " + String(repeating: "x", count: 200)))
        }

        try await store.clearAll()

        let clearedCount = try await store.count()
        XCTAssertEqual(clearedCount, 0)
        let clearedRows = try await store.fetch()
        XCTAssertEqual(clearedRows, [])
        await store.close()
        for suffix in ["", "-wal"] {
            let path = fileURL.path + suffix
            guard let data = FileManager.default.contents(atPath: path) else { continue }
            XCTAssertNil(data.range(of: Data(secret.utf8)), "Cleared text remained in history.sqlite\(suffix)")
        }
        // The store keeps working after a clear.
        let reopened = TranscriptHistoryStore(fileURL: fileURL)
        try await reopened.insert(NewTranscript(text: "after clear"))
        let afterClear = try await reopened.fetch()
        XCTAssertEqual(afterClear.map(\.text), ["after clear"])
    }

    func testFilesAreOwnerOnly() async throws {
        let store = TranscriptHistoryStore(fileURL: fileURL)
        try await store.insert(NewTranscript(text: "private"))

        for suffix in ["", "-wal", "-shm"] {
            let path = fileURL.path + suffix
            guard FileManager.default.fileExists(atPath: path) else {
                XCTAssertNotEqual(suffix, "", "history.sqlite was not created")
                continue
            }
            let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber
            XCTAssertEqual(mode?.intValue, 0o600, "history.sqlite\(suffix)")
        }
        let directoryMode = try FileManager.default.attributesOfItem(atPath: fileURL.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(directoryMode?.intValue, 0o700)
    }

    func testDefaultFileLocation() throws {
        let url = try XCTUnwrap(TranscriptHistoryStore.defaultFileURL())
        XCTAssertTrue(url.path.hasSuffix("Library/Application Support/Talkies/history.sqlite"), url.path)
    }

    // MARK: - Raw SQLite helpers

    private func openRaw() throws -> OpaquePointer {
        var db: OpaquePointer?
        guard sqlite3_open_v2(fileURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK, let db else {
            throw TranscriptHistoryError.open("test open failed")
        }
        return db
    }

    private func column(_ db: OpaquePointer, _ sql: String) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw TranscriptHistoryError.sqlite(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }
        var values: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "")
        }
        return values
    }

    private func scalarText(_ db: OpaquePointer, _ sql: String) throws -> String? {
        try column(db, sql).first
    }

    private func scalarInt(_ db: OpaquePointer, _ sql: String) throws -> Int64? {
        try scalarText(db, sql).flatMap { Int64($0) }
    }
}
