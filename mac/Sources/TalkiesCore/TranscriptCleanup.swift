import Foundation

public enum TranscriptStyle: String, CaseIterable, Codable, Sendable {
    case casual
    case semiCasual = "semi-casual"
    case semiFormal = "semi-formal"
    case formal
}

public enum TranscriptStructure: String, CaseIterable, Codable, Sendable {
    case prose
    case lists
}

public enum TranscriptContext: String, CaseIterable, Codable, Sendable {
    case general
    case email
}

public struct TranscriptCleanupOptions: Equatable, Sendable {
    public var style: TranscriptStyle
    public var structure: TranscriptStructure
    public var context: TranscriptContext

    public init(
        style: TranscriptStyle = .semiFormal,
        structure: TranscriptStructure = .prose,
        context: TranscriptContext = .general
    ) {
        self.style = style
        self.structure = structure
        self.context = context
    }

    public var controlLine: String {
        "[Styling: \(style.rawValue)] [Structure: \(structure.rawValue)] [Context: \(context.rawValue)]"
    }
}

/// On-device post-processing interface. Implementations must not send transcript text over a network.
public protocol TranscriptCleaner: Sendable {
    func clean(_ transcript: String, options: TranscriptCleanupOptions) async throws -> String
}

public enum S1MiniPrompt {
    public static let system = "You are a text normalizer for speech-to-text transcripts. The input begins with a control line specifying the styling, structure, and context settings; clean the transcript to match those settings and output only the cleaned text."

    /// Renders the Qwen3 chat prefix used by S1-mini, including its required empty thinking block.
    public static func render(transcript: String, options: TranscriptCleanupOptions) -> String {
        "<|im_start|>system\n\(system)<|im_end|>\n<|im_start|>user\n\(options.controlLine)\n\(transcript)<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    }
}
