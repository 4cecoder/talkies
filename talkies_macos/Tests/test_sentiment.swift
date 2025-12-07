#!/usr/bin/env swift

import Foundation
import NaturalLanguage

// Mocking the logic from SentimentPlugin to verify behavior
func analyze(text: String) -> (Double, String) {
    let tagger = NLTagger(tagSchemes: [.sentimentScore])
    tagger.string = text
    let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
    let score = Double(sentiment?.rawValue ?? "0") ?? 0.0
    
    let label: String
    if score > 0.5 { label = "Very Positive" }
    else if score > 0.1 { label = "Positive" }
    else if score < -0.5 { label = "Very Negative" }
    else if score < -0.1 { label = "Negative" }
    else { label = "Neutral" }
    
    return (score, label)
}

let testCases = [
    "I love using Talkies!": "Positive",
    "This is absolutely terrible and I hate it.": "Negative",
    "It is a book.": "Neutral",
    "I am extremely angry about this bug!": "Very Negative",
    "This is the best app I have ever used in my entire life!": "Very Positive"
]

print("🧪 Testing Sentiment Analysis Logic")
print("===================================")

var passed = 0
for (text, expectedBaseLabel) in testCases {
    let (score, label) = analyze(text: text)
    print("\n📝 Text: \"\(text)\"")
    print("   Score: \(score)")
    print("   Label: \(label)")
    
    // Check correctness
    var matches = false
    if expectedBaseLabel.contains("Positive") && score > 0.1 { matches = true }
    else if expectedBaseLabel.contains("Negative") && score < -0.1 { matches = true }
    else if expectedBaseLabel == "Neutral" && score >= -0.1 && score <= 0.1 { matches = true }
    
    if matches {
        print("   ✅ Verified")
        passed += 1
    } else {
        print("   ⚠️ Unexpected result (Expected: \(expectedBaseLabel))")
    }
}

print("\n===================================")
print("Tests Completed: \(passed)/\(testCases.count) passed")
