import XCTest
@testable import TalkiesInference

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

    func testCachedModelResolverRequiresModelAndTokenizerAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "talkies-whisper-cache-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        let modelFolder = root
            .appending(path: "models/argmaxinc/whisperkit-coreml/openai_whisper-tiny", directoryHint: .isDirectory)
        let modelAssets = [
            "config.json",
            "AudioEncoder.mlmodelc/weights/weight.bin",
            "MelSpectrogram.mlmodelc/weights/weight.bin",
            "TextDecoder.mlmodelc/weights/weight.bin",
        ]
        for asset in modelAssets {
            let assetURL = modelFolder.appending(path: asset)
            try FileManager.default.createDirectory(at: assetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: assetURL)
        }

        XCTAssertNil(WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root))
        XCTAssertTrue(WhisperKitRecognizer.shouldDownload(requested: true, hasVerifiedCache: false))

        let tokenizerURL = modelFolder.appending(path: "models/openai/whisper-tiny/tokenizer.json")
        try FileManager.default.createDirectory(at: tokenizerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1]).write(to: tokenizerURL)

        XCTAssertEqual(
            WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
            modelFolder
        )
        XCTAssertFalse(WhisperKitRecognizer.shouldDownload(requested: true, hasVerifiedCache: true))
    }

    func testTranscribesWithCachedModelWithoutResolvingItRemotely() async throws {
        guard ProcessInfo.processInfo.environment["TALKIES_RUN_WHISPERKIT_MODEL_TESTS"] == "1" else {
            throw XCTSkip("Set TALKIES_RUN_WHISPERKIT_MODEL_TESTS=1 to download and run the WhisperKit tiny model.")
        }

        let modelFolder: URL
        if let cachedFolder = WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny") {
            modelFolder = cachedFolder
        } else {
            modelFolder = try await WhisperKitRecognizer.downloadModel(variant: "openai_whisper-tiny")
        }
        let recognizer = await MainActor.run {
            WhisperKitRecognizer(modelName: "openai_whisper-tiny")
        }
        let resolvedModelFolder = try XCTUnwrap(
            WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny")
        )
        XCTAssertEqual(resolvedModelFolder.lastPathComponent, modelFolder.lastPathComponent)
        XCTAssertEqual(resolvedModelFolder.deletingLastPathComponent().path, modelFolder.deletingLastPathComponent().path)
        try await recognizer.initialize()

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
