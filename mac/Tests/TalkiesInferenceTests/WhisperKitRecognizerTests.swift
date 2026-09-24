import XCTest
import TalkiesInference

final class WhisperKitRecognizerTests: XCTestCase {
    func testRecordingIsDeletedWhenRecognizerIsNotReady() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("talkies-recording-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))

        let recognizer = await MainActor.run { WhisperKitRecognizer() }
        do {
            _ = try await recognizer.transcribe(audioURL, deleteAudioAfterProcessing: true)
            XCTFail("An uninitialized recognizer must reject transcription")
        } catch WhisperKitRecognizerError.notInitialized {
            // Expected: cleanup must also run on this failure path.
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    func testSourceAudioIsKeptWhenCleanupIsNotRequested() async throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("talkies-import-\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let recognizer = await MainActor.run { WhisperKitRecognizer() }
        do {
            _ = try await recognizer.transcribe(audioURL)
            XCTFail("An uninitialized recognizer must reject transcription")
        } catch WhisperKitRecognizerError.notInitialized {
            // Source files supplied without recording cleanup remain available.
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: audioURL.path))
    }
}
