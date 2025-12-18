import SwiftUI
import Foundation
import Combine
import WhisperKit
import AVFoundation

struct TranscriptSegment: Identifiable, Codable {
    let id = UUID()
    let timestamp: String
    let text: String
    let start: Double
    let end: Double

    enum CodingKeys: String, CodingKey {
        case timestamp, text, start, end
    }
}

/// Pipeline stages for status indication
enum PipelineStage: Equatable {
    case idle
    case recording
    case transcribing
    case enhancingOllama
    case enhancingLMStudio
    case insertingText
    case complete
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .enhancingOllama: return "Enhancing with Ollama..."
        case .enhancingLMStudio: return "Enhancing with LM Studio..."
        case .insertingText: return "Inserting text..."
        case .complete: return "Complete"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .orange
        case .enhancingOllama, .enhancingLMStudio: return .purple
        case .insertingText: return .blue
        case .complete: return .green
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .enhancingOllama, .enhancingLMStudio: return "sparkles"
        case .insertingText: return "text.cursor"
        case .complete: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
class TranscriptionService: ObservableObject {
    @Published var segments: [TranscriptSegment] = []
    @Published var isTranscribing = false
    @Published var currentText = ""
    @Published var error: String?
    @Published var isDownloadingModel = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = "Initializing..."
    @Published var pipelineStage: PipelineStage = .idle

    private var whisperKit: WhisperKit?
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var transcriptionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var isInitialized = false
    private var modelName: String = "openai_whisper-base"

    var onTranscriptionComplete: ((String) -> Void)?
    
    // Statistics
    var totalWords: Int {
        segments.flatMap { $0.text.components(separatedBy: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }
    
    var wordsPerMinute: Int {
        guard !segments.isEmpty else { return 0 }
        
        let totalDuration = segments.last?.end ?? 0
        guard totalDuration > 0 else { return 0 }
        
        return Int((Double(totalWords) / totalDuration) * 60)
    }
    
    init() {
        Task {
            await initializeWhisperKit()
        }
    }

    private func initializeWhisperKit() async {
        statusMessage = "Checking for Whisper model..."

        do {
            isDownloadingModel = true
            statusMessage = "Loading Whisper model..."
            print("📥 Initializing WhisperKit with model: \(modelName)")

            // Initialize WhisperKit - will download if needed
            whisperKit = try await WhisperKit(
                model: modelName,
                verbose: true,
                logLevel: .debug
            )

            isInitialized = true
            isDownloadingModel = false
            statusMessage = "Ready to transcribe"
            error = nil
            print("✅ WhisperKit initialized successfully")

        } catch {
            isDownloadingModel = false
            self.error = "Failed to initialize: \(error.localizedDescription)"
            statusMessage = "Initialization failed"
            print("❌ WhisperKit initialization error: \(error)")
        }
    }

    func startTranscription(model: String = "base", language: String? = nil) {
        print("      TranscriptionService.startTranscription() - START")
        print("         isInitialized: \(isInitialized)")
        print("         whisperKit != nil: \(whisperKit != nil)")

        guard isInitialized, whisperKit != nil else {
            print("         ❌ WhisperKit not initialized yet")
            error = "WhisperKit not initialized yet. Please wait..."
            return
        }

        print("         ✓ Setting isTranscribing = true")
        isTranscribing = true
        error = nil
        print("      TranscriptionService.startTranscription() - DONE")
    }

    func stopTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    func transcribeAudioFile(_ audioURL: URL) async {
        guard let whisperKit = whisperKit else {
            await MainActor.run {
                error = "WhisperKit not initialized"
                statusMessage = "Error: Not initialized"
            }
            return
        }

        await MainActor.run {
            isTranscribing = true
            statusMessage = "Transcribing audio..."
            error = nil
        }

        print("🎙️ Starting transcription of: \(audioURL.lastPathComponent)")

        do {
            // Transcribe the audio file with options
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.2,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                clipTimestamps: [0]
            )

            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            print("✅ Transcription complete - \(results.count) results")

            await MainActor.run {
                self.processWhisperResults(results)
                self.statusMessage = "Transcription complete"
                self.isTranscribing = false

                // Get full transcribed text
                let fullText = self.segments.map { $0.text }.joined(separator: " ")
                self.currentText = fullText

                // Trigger callback with transcribed text
                self.onTranscriptionComplete?(fullText)
            }
        } catch {
            print("❌ Transcription error: \(error)")
            await MainActor.run {
                self.error = "Transcription failed: \(error.localizedDescription)"
                self.statusMessage = "Transcription failed"
                self.isTranscribing = false
            }
        }
    }

    private func processWhisperResults(_ results: [TranscriptionResult]) {
        // Clear previous segments
        segments.removeAll()

        for result in results {
            for segment in result.segments {
                let transcriptSegment = TranscriptSegment(
                    timestamp: formatTimestamp(Double(segment.start)),
                    text: segment.text,
                    start: Double(segment.start),
                    end: Double(segment.end)
                )
                segments.append(transcriptSegment)
            }
        }
    }
    
    private func formatTimestamp(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
    
    func exportVTT() -> String {
        var vttContent = "WEBVTT\n\n"
        
        for segment in segments {
            vttContent += "\(segment.timestamp) --> \(formatTimestamp(segment.end))\n"
            vttContent += "\(segment.text)\n\n"
        }
        
        return vttContent
    }
    
    func exportSRT() -> String {
        var srtContent = ""
        
        for (index, segment) in segments.enumerated() {
            srtContent += "\(index + 1)\n"
            srtContent += "\(formatSRTTime(segment.start)) --> \(formatSRTTime(segment.end))\n"
            srtContent += "\(segment.text)\n\n"
        }
        
        return srtContent
    }
    
    func exportTXT() -> String {
        return segments.map { $0.text }.joined(separator: "\n")
    }
    
    private func formatSRTTime(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    func clearTranscript() {
        segments.removeAll()
        currentText = ""
        error = nil
    }
    
    func setAudioFileURL(_ url: URL) {
        Task {
            await transcribeAudioFile(url)
        }
    }

    nonisolated deinit {
        // Cancel transcription task
        transcriptionTask?.cancel()
    }
}