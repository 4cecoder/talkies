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
        try Data([0x7B, 0x7D]).write(to: tokenizerURL)
        XCTAssertNil(WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
                     "A nonempty but structurally invalid tokenizer must not qualify as an offline cache.")
        XCTAssertTrue(WhisperKitRecognizer.shouldDownload(requested: true, hasVerifiedCache: false))

        try Data(#"{"model":{"type":"BPE","vocab":{"token":"not-an-id"},"merges":[]}}"#.utf8).write(to: tokenizerURL)
        XCTAssertNil(WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
                     "Tokenizer vocabulary values must decode as token IDs.")

        try Data(#"{"model":{"type":"BPE","vocab":{"token":0},"merges":[["one"]]}}"#.utf8).write(to: tokenizerURL)
        XCTAssertNil(WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
                     "Malformed merge tuples must not reach WhisperKit's unchecked BPE parser.")

        try Data(#"{"model":{"type":"BPE","vocab":{"token":0},"merges":["onlyone"]}}"#.utf8).write(to: tokenizerURL)
        XCTAssertNil(WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
                     "Legacy merge strings must contain exactly two tokens.")

        try Data(#"{"model":{"type":"BPE","vocab":{"token":0},"merges":[]}}"#.utf8).write(to: tokenizerURL)

        XCTAssertEqual(
            WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
            modelFolder
        )
        XCTAssertFalse(WhisperKitRecognizer.shouldDownload(requested: true, hasVerifiedCache: true))

        for validMergeJSON in [
            #"{"model":{"type":"BPE","vocab":{"one":0,"two":1},"merges":["one two"]}}"#,
            #"{"model":{"type":"BPE","vocab":{"one":0,"two":1},"merges":[["one","two"]]}}"#,
        ] {
            try Data(validMergeJSON.utf8).write(to: tokenizerURL)
            XCTAssertEqual(
                WhisperKitRecognizer.cachedModelFolder(modelName: "openai_whisper-tiny", downloadBase: root),
                modelFolder,
                "Both WhisperKit-supported BPE merge encodings should qualify as valid cache data."
            )
        }

        let overrideFolder = root.appending(path: "custom-model-location", directoryHint: .isDirectory)
        for asset in modelAssets {
            let assetURL = overrideFolder.appending(path: asset)
            try FileManager.default.createDirectory(at: assetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: assetURL)
        }
        XCTAssertNil(WhisperKitRecognizer.verifiedModelFolder(
            overrideFolder,
            modelName: "openai_whisper-tiny",
            downloadBase: root
        ))
        XCTAssertTrue(WhisperKitRecognizer.shouldDownload(requested: true, hasVerifiedCache: false))

        let overrideTokenizer = overrideFolder.appending(path: "tokenizer.json")
        try Data(#"{"model":{"type":"BPE","vocab":{"token":0},"merges":[]}}"#.utf8).write(to: overrideTokenizer)
        XCTAssertEqual(
            WhisperKitRecognizer.verifiedModelFolder(
                overrideFolder,
                modelName: "openai_whisper-tiny",
                downloadBase: root
            ),
            overrideFolder
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
        try await recognizer.initialize(modelFolder: modelFolder)

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
