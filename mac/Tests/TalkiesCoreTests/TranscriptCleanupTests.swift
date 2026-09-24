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
}
