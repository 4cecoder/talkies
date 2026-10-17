import Foundation
import XCTest
@testable import TalkiesInference

final class PhononAcceptanceTests: XCTestCase {
    /// Runs Phonon-2 on a provisioned, verified bundle without downloading anything.
    func testProvisionedPhononBundleTranscribesFixtureOffline() async throws {
        guard let path = ProcessInfo.processInfo.environment["TALKIES_PHONON_MODEL_DIR"] else {
            throw XCTSkip("Set TALKIES_PHONON_MODEL_DIR to a provisioned Phonon-2-CoreML folder.")
        }
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "tests/fixtures/jfk.wav")

        let recognizer = await MainActor.run {
            PhononRecognizer(allowDownload: false, modelDirectory: URL(fileURLWithPath: path))
        }
        try await recognizer.prepare()
        let segments = try await recognizer.transcribe(fixtureURL, vocabulary: [], onProgress: nil)
        let text = segments.map(\.text).joined(separator: " ").lowercased()
        XCTAssertTrue(text.contains("ask not what your country can do for you"), text)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixtureURL.path), "recognizer must not delete caller audio")
    }
}
