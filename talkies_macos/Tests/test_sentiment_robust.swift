
// This file is intended to be compiled alongside SentimentAnalyzer.swift
// Usage: swiftc Sources/Talkies/Plugins/SentimentAnalyzer.swift Tests/test_sentiment_robust.swift -o test_bin && ./test_bin

import Foundation

@main
struct SentimentTestRunner {
    static var passCount = 0
    static var failCount = 0

    static func assert(_ condition: Bool, _ message: String) {
        if condition {
            passCount += 1
            print("✅ PASS: \(message)")
        } else {
            failCount += 1
            print("❌ FAIL: \(message)")
        }
    }

    static func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual == expected {
            passCount += 1
            print("✅ PASS: \(message)")
        } else {
            failCount += 1
            print("❌ FAIL: \(message) - Expected \(expected), got \(actual)")
        }
    }

    static func main() {
        print("🧪 Starting Robust Sentiment Analysis Tests...")
        print("------------------------------------------")

        // 1. Test Neutral/Empty
        let emptyResult = SentimentAnalyzer.analyze(text: "")
        assertEqual(emptyResult.score, 0.0, "Empty string should be 0.0")
        assertEqual(emptyResult.sentiment, .neutral, "Empty string should be Neutral")

        // 2. Test Positive
        let posResult = SentimentAnalyzer.analyze(text: "I like this feature.")
        assert(posResult.score > 0.0, "Positive text should have score > 0")
        assert(posResult.sentiment == .positive || posResult.sentiment == .veryPositive, "Should be Positive or Very Positive")

        // 3. Test Negative
        let negResult = SentimentAnalyzer.analyze(text: "I hate bugs.")
        assert(negResult.score < 0.0, "Negative text should have score < 0")
        assert(negResult.sentiment == .negative || negResult.sentiment == .veryNegative, "Should be Negative or Very Negative")

        // 4. Test Strong Emotions
        let veryPosResult = SentimentAnalyzer.analyze(text: "This is the most amazing, wonderful, and fantastic thing ever!")
        assertEqual(veryPosResult.sentiment, .veryPositive, "Strongly positive text should be Very Positive")

        let veryNegResult = SentimentAnalyzer.analyze(text: "This is absolutely completely terrible and awful.")
        assertEqual(veryNegResult.sentiment, .veryNegative, "Strongly negative text should be Very Negative")

        // 5. Test Mixed/Complex (Edge cases)
        let sarcasm = "Oh great, another error."
        let sarcasmResult = SentimentAnalyzer.analyze(text: sarcasm)
        print("ℹ️ Sarcasm score: \(sarcasmResult.score)")

        // 6. Test Emoji Mapping
        assertEqual(SentimentAnalyzer.Sentiment.veryPositive.emoji, "🤩", "Very Positive emoji check")
        assertEqual(SentimentAnalyzer.Sentiment.negative.emoji, "🙁", "Negative emoji check")

        // 7. Test Label Mapping
        assertEqual(SentimentAnalyzer.Sentiment.neutral.label, "Neutral", "Neutral label check")

        print("------------------------------------------")
        print("Tests Finished.")
        print("Passed: \(passCount)")
        print("Failed: \(failCount)")

        if failCount == 0 {
            print("✨ ALL TESTS PASSED")
            exit(0)
        } else {
            print("🔥 SOME TESTS FAILED")
            exit(1)
        }
    }
}
