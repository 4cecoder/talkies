import XCTest
@testable import TalkiesCore

final class TranscriptCleanupTests: XCTestCase {
    func testS1MiniPromptMatchesModelCard() {
        XCTAssertEqual(
            S1MiniPrompt.system,
            "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."
        )
    }

    func testDefaultControlLineUsesSupportedValues() {
        XCTAssertEqual(
            TranscriptCleanupOptions().controlLine,
            "[Styling: semi-formal] [Structure: prose] [Context: general]"
        )
    }

    func testCustomControlLineUsesOnlySupportedOptions() {
        let options = TranscriptCleanupOptions(style: .casual, structure: .lists, context: .email)
        XCTAssertEqual(options.controlLine, "[Styling: casual] [Structure: lists] [Context: email]")
    }

    func testPromptUsesS1MiniQwenChatPrefixAndDisabledThinkingBlock() {
        XCTAssertEqual(
            S1MiniPrompt.render(transcript: "raw words", options: TranscriptCleanupOptions()),
            "<|im_start|>system\n\(S1MiniPrompt.system)<|im_end|>\n<|im_start|>user\n[Styling: semi-formal] [Structure: prose] [Context: general]\nraw words<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
        )
    }

    func testPromptMatchesSharedCrossPlatformGoldenFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "linux/src/testdata/s1-mini-prompt-golden.json")
        let fixture = try JSONDecoder().decode(PromptGoldenFixture.self, from: Data(contentsOf: fixtureURL))

        for testCase in fixture.cases {
            let options = TranscriptCleanupOptions(
                style: try XCTUnwrap(TranscriptStyle(rawValue: testCase.style)),
                structure: try XCTUnwrap(TranscriptStructure(rawValue: testCase.structure)),
                context: try XCTUnwrap(TranscriptContext(rawValue: testCase.context))
            )
            XCTAssertEqual(S1MiniPrompt.render(transcript: testCase.transcript, options: options), testCase.expected)
        }
    }

    func testCleanupResultMatchesSharedCrossPlatformGoldenFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "linux/src/testdata/s1-mini-cleanup-result-golden.json")
        let fixture = try JSONDecoder().decode(CleanupResultGoldenFixture.self, from: Data(contentsOf: fixtureURL))

        for testCase in fixture.cases {
            XCTAssertEqual(
                TranscriptCleanupResult.resolve(original: testCase.original, modelOutput: testCase.modelOutput),
                testCase.expected
            )
        }
    }
}

private struct PromptGoldenFixture: Decodable {
    let cases: [PromptCase]

    struct PromptCase: Decodable {
        let transcript: String
        let style: String
        let structure: String
        let context: String
        let expected: String
    }
}

private struct CleanupResultGoldenFixture: Decodable {
    let cases: [Case]

    struct Case: Decodable {
        let original: String
        let modelOutput: String
        let expected: String
    }
}
