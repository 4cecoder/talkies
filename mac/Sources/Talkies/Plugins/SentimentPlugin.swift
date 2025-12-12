import SwiftUI
import NaturalLanguage

// MARK: - Sentiment Analysis Plugin
class SentimentPlugin: TalkiesPlugin, ObservableObject {
    let id = "sentiment"
    let name = "Sentiment Analysis"
    let description = "Analyze the emotional tone of text using Apple's Natural Language framework"
    let icon = "face.smiling"

    @Published var isEnabled = false {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "sentiment.isEnabled") }
    }
    
    @Published var text: String = ""
    @Published var sentimentScore: Double = 0.0
    @Published var sentimentLabel: String = "Neutral"
    @Published var sentimentEmoji: String = "😐"
    @Published var isAnalyzing = false
    
    init() {
        isEnabled = UserDefaults.standard.bool(forKey: "sentiment.isEnabled")
    }
    
    func analyzeSentiment(text: String) {
        guard !text.isEmpty else { return }
        
        isAnalyzing = true
        
        Task {
            // Use the isolated analyzer logic
            let result = SentimentAnalyzer.analyze(text: text)
            
            await MainActor.run {
                self.sentimentScore = result.score
                self.sentimentLabel = result.sentiment.label
                self.sentimentEmoji = result.sentiment.emoji
                self.isAnalyzing = false
            }
        }
    }
    
    // Removed private updateLabelAndEmoji as logic is now in SentimentAnalyzer

    func settingsView() -> AnyView {
        AnyView(SentimentSettingsView(plugin: self))
    }
}

// MARK: - Settings View
struct SentimentSettingsView: View {
    @ObservedObject var plugin: SentimentPlugin
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Intro Card
                SentimentInfoCard()
                
                // Input Card
                SentimentInputCard(text: $plugin.text)
                
                // Analyze Button
                Button(action: {
                    plugin.analyzeSentiment(text: plugin.text)
                }) {
                    HStack {
                        if plugin.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(plugin.isAnalyzing ? "Analyzing..." : "Analyze Sentiment")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(plugin.text.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(plugin.text.isEmpty)
                
                // Result Card
                if !plugin.text.isEmpty {
                    SentimentResultCard(
                        score: plugin.sentimentScore,
                        label: plugin.sentimentLabel,
                        emoji: plugin.sentimentEmoji
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - UI Cards
struct SentimentInfoCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Native Sentiment Analysis")
                    .font(.headline)
                
                Text("Uses device-local Natural Language processing to detect the emotional tone of text. No data leaves your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SentimentInputCard: View {
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text to Analyze")
                .font(.headline)
            
            TextEditor(text: $text)
                .font(.body)
                .frame(height: 120)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("Enter text to check its sentiment score (-1.0 to 1.0)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SentimentResultCard: View {
    let score: Double
    let label: String
    let emoji: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Analysis Result")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 30) {
                // Emoji Display
                Text(emoji)
                    .font(.system(size: 64))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(label)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)
                    
                    Text("Score: \(String(format: "%.2f", score))")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
            
            // Gauge Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                    
                    // Gradient Bar
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.red, .gray, .green]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 20)
                    
                    // Indicator
                    // Map score -1...1 to 0...width
                    // -1 -> 0
                    // 0 -> 0.5
                    // 1 -> 1
                    // (score + 1) / 2
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: 4, height: 28)
                        .offset(x: (CGFloat(score + 1) / 2.0) * geometry.size.width - 2)
                        .shadow(radius: 2)
                }
            }
            .frame(height: 28)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    var scoreColor: Color {
        if score > 0.1 { return .green }
        if score < -0.1 { return .red }
        return .secondary
    }
}
