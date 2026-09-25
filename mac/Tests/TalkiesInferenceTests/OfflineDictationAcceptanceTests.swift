import Foundation
import XCTest
@testable import TalkiesAccessibility
@testable import TalkiesInference

final class OfflineDictationAcceptanceTests: XCTestCase {
    func testCachedASRCleanupAndInsertionCompleteWithCleanupModelNetworkDenied() async throws {
        guard ProcessInfo.processInfo.environment["TALKIES_RUN_OFFLINE_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Set TALKIES_RUN_OFFLINE_ACCEPTANCE=1 after provisioning both local models.")
        }

        // CI provisions both models in earlier setup steps. This acceptance
        // path never calls a downloader: WhisperKit is initialized with
        // download=false, and the cleanup store rejects every URLSession
        // request, so a missing or corrupt model fails closed.
        let whisperModelFolder = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-tiny")
        guard FileManager.default.fileExists(atPath: whisperModelFolder.path) else {
            throw OfflineAcceptanceError.missingWhisperModel
        }
        let s1MiniDirectory = try S1MiniModelStore.modelDirectory()
        let deniedConfiguration = URLSessionConfiguration.ephemeral
        deniedConfiguration.protocolClasses = [AcceptanceNetworkDeniedURLProtocol.self]
        let deniedSession = URLSession(configuration: deniedConfiguration)
        let cleaner = S1MiniCleaner(
            modelStore: S1MiniModelStore(session: deniedSession, modelDirectory: s1MiniDirectory)
        )

        let recognizer = await MainActor.run { WhisperKitRecognizer(modelName: "openai_whisper-tiny") }
        try await recognizer.initialize(download: false, modelFolder: whisperModelFolder)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "tests/fixtures/jfk.wav")
        let recordingURL = FileManager.default.temporaryDirectory
            .appending(path: "talkies-offline-acceptance-\(UUID().uuidString).wav")
        try FileManager.default.copyItem(at: fixtureURL, to: recordingURL)
        defer { try? FileManager.default.removeItem(at: recordingURL) }

        let segments = try await recognizer.transcribe(recordingURL, deleteAudioAfterProcessing: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recordingURL.path), "Processed recording should be removed")

        let rawTranscript = segments.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(rawTranscript.isEmpty, "Cached local ASR should recognize the provisioned sample")

        let cleanedTranscript = try await cleaner.clean(rawTranscript)
        XCTAssertFalse(cleanedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Acceptance Field")
        let accessibilityClient = await MainActor.run { AcceptanceTextAccessibilityClient() }
        let inserter = await MainActor.run { TextInserter(accessibilityClient: accessibilityClient) }
        let insertionResult = await inserter.insertTextAtCursor(cleanedTranscript, into: destination)
        let insertedText = await MainActor.run { accessibilityClient.insertedText }

        XCTAssertEqual(insertionResult, .inserted(applicationName: "Acceptance Field"))
        XCTAssertEqual(insertedText, cleanedTranscript)
    }
}

private enum OfflineAcceptanceError: Error {
    case missingWhisperModel
}

private final class AcceptanceNetworkDeniedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

@MainActor
private final class AcceptanceTextAccessibilityClient: TextAccessibilityClient {
    let currentProcessIdentifier: pid_t = 9000
    var frontmostProcessIdentifier: pid_t? = 4242
    private(set) var insertedText: String?

    func frontmostApplication() -> (processIdentifier: pid_t, name: String)? {
        (4242, "Acceptance Field")
    }

    func isTrusted() -> Bool { true }

    func setSelectedText(_ text: String, in processIdentifier: pid_t) -> FocusedTextInsertionAttempt {
        guard processIdentifier == 4242 else { return .writeDenied }
        insertedText = text
        return .inserted
    }
}
