import Foundation
import NaturalLanguage

/// A pure logic struct for performing sentiment analysis.
/// This separates the business logic from the UI/Plugin layer.
struct SentimentAnalyzer {
    
    enum Sentiment {
        case veryPositive
        case positive
        case neutral
        case negative
        case veryNegative
        
        var label: String {
            switch self {
            case .veryPositive: return "Very Positive"
            case .positive: return "Positive"
            case .neutral: return "Neutral"
            case .negative: return "Negative"
            case .veryNegative: return "Very Negative"
            }
        }
        
        var emoji: String {
            switch self {
            case .veryPositive: return "🤩"
            case .positive: return "🙂"
            case .neutral: return "😐"
            case .negative: return "🙁"
            case .veryNegative: return "🤬"
            }
        }
    }
    
    struct Result {
        let score: Double
        let sentiment: Sentiment
    }
    
    /// Analyzes the sentiment of the given text.
    /// - Parameter text: The text to analyze.
    /// - Returns: A Result containing the score and sentiment classification.
    static func analyze(text: String) -> Result {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        // We use .paragraph to get an overall sentiment, but for short text .document is also fine.
        // If the text is empty or analysis fails, we get nil -> 0.0 (Neutral).
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        let score = Double(sentiment?.rawValue ?? "0") ?? 0.0
        
        return Result(score: score, sentiment: classify(score: score))
    }
    
    /// Classifies a raw score into a Sentiment enum.
    /// - Parameter score: The sentiment score from -1.0 to 1.0.
    /// - Returns: The Sentiment classification.
    private static func classify(score: Double) -> Sentiment {
        if score > 0.5 { return .veryPositive }
        if score > 0.1 { return .positive }
        if score < -0.5 { return .veryNegative }
        if score < -0.1 { return .negative }
        return .neutral
    }
}
