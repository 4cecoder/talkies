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

        XCTAssertTrue(cleaned.localizedCaseInsensitiveContains("send the report"), cleaned)
        XCTAssertTrue(cleaned.localizedCaseInsensitiveContains("Thursday"), cleaned)
        XCTAssertFalse(cleaned.localizedCaseInsensitiveContains("Friday"), cleaned)
        XCTAssertFalse(cleaned.localizedCaseInsensitiveContains("um"), cleaned)
        XCTAssertFalse(cleaned.localizedCaseInsensitiveContains("like"), cleaned)
        XCTAssertFalse(cleaned.localizedCaseInsensitiveContains("the the"), cleaned)

        let followUp = try await cleaner.clean(
            "um please schedule the review for Wednesday no Friday",
            options: TranscriptCleanupOptions()
        )
        XCTAssertTrue(followUp.localizedCaseInsensitiveContains("Friday"), followUp)
        XCTAssertFalse(followUp.localizedCaseInsensitiveContains("Wednesday"), followUp)
        XCTAssertFalse(followUp.localizedCaseInsensitiveContains("um"), followUp)
    }
}
