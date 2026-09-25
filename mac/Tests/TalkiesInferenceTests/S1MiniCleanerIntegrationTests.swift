import XCTest
import TalkiesCore
@testable import TalkiesInference
import Foundation

final class S1MiniCleanerIntegrationTests: XCTestCase {
    func testCleansTranscriptWithPinnedS1MiniModel() async throws {
        guard ProcessInfo.processInfo.environment["TALKIES_RUN_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set TALKIES_RUN_MODEL_TESTS=1 to download and run the pinned S1-mini weights.")
        }

        let provisioningStore = S1MiniModelStore()
        let modelURL = try await provisioningStore.ensureModelAvailable()

        let networkDeniedConfiguration = URLSessionConfiguration.ephemeral
        networkDeniedConfiguration.protocolClasses = [NetworkDeniedURLProtocol.self]
        let networkDeniedSession = URLSession(configuration: networkDeniedConfiguration)
        let networkDeniedStore = S1MiniModelStore(
            session: networkDeniedSession,
            modelDirectory: modelURL.deletingLastPathComponent()
        )
        let cleaner = S1MiniCleaner(modelStore: networkDeniedStore)
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

private final class NetworkDeniedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
