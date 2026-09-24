import XCTest
import TalkiesCore
import TalkiesInference

final class S1MiniCleanerIntegrationTests: XCTestCase {
    func testCleansTranscriptWithPinnedS1MiniModel() async throws {
        guard ProcessInfo.processInfo.environment["TALKIES_RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set TALKIES_RUN_MODEL_TESTS=1 to download and run the pinned S1-mini weights.")
        }

        let cleaner = S1MiniCleaner()
        let cleaned = try await cleaner.clean(
            "so um i need to like send the the report by uh friday no wait make that thursday",
            options: TranscriptCleanupOptions()
        )

        XCTAssertEqual(cleaned, "I need to send the report by Thursday.")
    }
}
