import Foundation

enum TranscriptStyle: String, CaseIterable, Identifiable {
    case casual
    case semiCasual = "semi-casual"
    case semiFormal = "semi-formal"
    case formal

    var id: String { rawValue }
}

enum TranscriptStructure: String, CaseIterable, Identifiable {
    case prose
    case lists

    var id: String { rawValue }
}

enum TranscriptContext: String, CaseIterable, Identifiable {
    case general
    case email

    var id: String { rawValue }
}

struct TranscriptCleanupOptions {
    var style: TranscriptStyle = .semiFormal
    var structure: TranscriptStructure = .prose
    var context: TranscriptContext = .general

    var controlLine: String {
        "[Styling: \(style.rawValue)] [Structure: \(structure.rawValue)] [Context: \(context.rawValue)]"
    }
}

enum S1MiniPrompt {
    static let system = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."

    static func render(transcript: String, options: TranscriptCleanupOptions) -> String {
        let normalized = transcript.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n"))
        return "<|im_start|>system\n\(system)<|im_end|>\n<|im_start|>user\n\(options.controlLine)\n\(normalized)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }

    static func resolve(original: String, output: String) -> String {
        let cleaned = output.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n"))
        return cleaned.isEmpty ? original : cleaned
    }
}
