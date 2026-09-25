import XCTest
import TalkiesInference
import WhisperKit

final class WhisperKitRecognizerTests: XCTestCase {
    func testRecognizerConstructionDoesNotLoadModel() async {
        let recognizer = await MainActor.run { WhisperKitRecognizer() }
        let isReady = await MainActor.run { recognizer.isReady }

        XCTAssertFalse(isReady)
    }

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

    func testTranscribesWithCachedModelWhenDownloadsAreDisabled() async throws {
        guard ProcessInfo.processInfo.environment["TALKIES_RUN_WHISPERKIT_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set TALKIES_RUN_WHISPERKIT_MODEL_TESTS=1 to download and run the WhisperKit tiny model.")
        }

        let modelFolder = try await WhisperKit.download(variant: "openai_whisper-tiny")
        let recognizer = await MainActor.run {
            WhisperKitRecognizer(modelName: "openai_whisper-tiny")
        }
        try await recognizer.initialize(download: false, modelFolder: modelFolder)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "tests/fixtures/jfk.wav")
        let segments = try await recognizer.transcribe(fixtureURL)
        let transcript = segments.map(\.text).joined(separator: " ")

        XCTAssertTrue(transcript.localizedCaseInsensitiveContains("country"), transcript)
    }
}
