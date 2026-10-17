import XCTest
import TalkiesCore
@testable import TalkiesInference

@MainActor
final class SpeechRecognizerChainTests: XCTestCase {
    private final class FakeRecognizer: LocalSpeechRecognizer {
        nonisolated let runtimeID: SpeechRuntimeID
        var isReady = false
        var isInstalledLocally = false
        var prepareError: Error?
        var transcribeError: Error?
        var segments: [TranscriptSegment]
        private(set) var transcribeCalls = 0

        init(_ id: SpeechRuntimeID, text: String) {
            runtimeID = id
            segments = text.isEmpty ? [] : [TranscriptSegment(timestamp: "00:00:00.000", text: text, start: 0, end: 1)]
        }

        func prepare() async throws {
            if let prepareError { throw prepareError }
            isReady = true
        }

        func transcribe(_ audioURL: URL, vocabulary: [String], onProgress: (@Sendable (Double) -> Void)?) async throws -> [TranscriptSegment] {
            transcribeCalls += 1
            if let transcribeError { throw transcribeError }
            return segments
        }
    }

    private struct Failure: LocalizedError { var errorDescription: String? { "boom" } }
    private let audio = URL(fileURLWithPath: "/dev/null")

    func testAutomaticPrefersPhonon() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [whisper, phonon]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .phonon)
        XCTAssertEqual(result.segments.map(\.text), ["phonon"])
        XCTAssertTrue(result.fallbacks.isEmpty)
        XCTAssertEqual(whisper.transcribeCalls, 0)
    }

    func testFallsBackToWhisperWhenPhononCannotLoad() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        phonon.prepareError = Failure()
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .whisper)
        XCTAssertEqual(result.fallbacks, [.init(runtime: .phonon, error: "boom")])
    }

    func testFallsBackToWhisperWhenPhononTranscriptionFails() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        phonon.transcribeError = Failure()
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .whisper)
        XCTAssertEqual(result.segments.map(\.text), ["whisper"])
    }

    func testEmptyPhononResultIsNoSpeechNotAFailure() async throws {
        let phonon = FakeRecognizer(.phonon, text: "")
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .phonon)
        XCTAssertTrue(result.segments.isEmpty)
        XCTAssertEqual(whisper.transcribeCalls, 0)
    }

    func testUsesReadyWhisperWhilePhononIsStillPreparing() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        whisper.isReady = true
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .whisper)
        XCTAssertEqual(phonon.transcribeCalls, 0)
        XCTAssertEqual(result.fallbacks.map(\.runtime), [.phonon])
    }

    func testWaitsForPhononWhenNothingElseIsReady() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
        XCTAssertEqual(result.runtime, .phonon)
    }

    func testWhisperPreferenceSkipsPhonon() async throws {
        let phonon = FakeRecognizer(.phonon, text: "phonon")
        let whisper = FakeRecognizer(.whisper, text: "whisper")
        let result = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .whisper)
        XCTAssertEqual(result.runtime, .whisper)
        XCTAssertEqual(phonon.transcribeCalls, 0)
    }

    func testThrowsLastErrorWhenEveryRuntimeFails() async {
        let phonon = FakeRecognizer(.phonon, text: "")
        phonon.prepareError = Failure()
        let whisper = FakeRecognizer(.whisper, text: "")
        whisper.transcribeError = Failure()
        do {
            _ = try await SpeechRecognizerChain(recognizers: [phonon, whisper]).transcribe(audio, preference: .automatic)
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "boom")
        }
    }

    func testWhisperIsAlwaysTheLastRuntime() {
        for preference in SpeechEnginePreference.allCases {
            XCTAssertEqual(preference.runtimeOrder.last, .whisper)
        }
    }
}
