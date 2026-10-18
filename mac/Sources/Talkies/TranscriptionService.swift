import SwiftUI
import Foundation
import Combine
import AVFoundation
import TalkiesCore
import TalkiesInference

/// Pipeline stages for status indication
enum PipelineStage: Equatable {
    case idle
    case loadingModel
    case requestingMicrophonePermission
    case recording
    case transcribing
    case enhancingOllama
    case enhancingLMStudio
    case cleaningS1Mini
    case cleanupFallback
    case insertingText
    case clipboardFallback(String)
    case noSpeech
    case complete
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .loadingModel: return "Loading speech model..."
        case .requestingMicrophonePermission: return "Microphone access needed"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .enhancingOllama: return "Enhancing with Ollama..."
        case .enhancingLMStudio: return "Enhancing with LM Studio..."
        case .cleaningS1Mini: return "Cleaning with S1-mini..."
        case .cleanupFallback: return "Using the raw transcript"
        case .insertingText: return "Inserting text..."
        case .clipboardFallback: return "Manual paste needed"
        case .noSpeech: return "No speech detected"
        case .complete: return "Complete"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .idle, .complete: return .green
        case .loadingModel, .requestingMicrophonePermission: return .orange
        case .recording: return .red
        case .transcribing: return .orange
        case .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini: return .purple
        case .cleanupFallback, .clipboardFallback, .noSpeech: return .orange
        case .insertingText: return .blue
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .idle: return "checkmark.circle.fill"
        case .loadingModel: return "arrow.down.circle.fill"
        case .requestingMicrophonePermission: return "mic.badge.ellipsis"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini: return "sparkles"
        case .cleanupFallback: return "text.quote"
        case .insertingText: return "text.cursor"
        case .clipboardFallback: return "doc.on.clipboard"
        case .noSpeech: return "waveform"
        case .complete: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

/// Recognizer output for one recording, carried through cleanup so the saved history entry
/// records the runtime that actually produced the text.
struct RecognizedDictation: Sendable {
    let text: String
    let runtime: SpeechRuntimeID
    let durationMs: Int64?
}

@MainActor
class TranscriptionService: ObservableObject {
    @Published var segments: [TranscriptSegment] = []
    @Published var isTranscribing = false
    @Published var currentText = ""
    @Published var error: String?
    @Published var isDownloadingModel = false
    @Published var downloadProgress: Double = 0.0
    @Published var transcriptionProgress: Double?
    @Published var statusMessage: String = "Ready to dictate"
    @Published var pipelineStage: PipelineStage = .idle

    private let recognizers = SpeechRecognizerChain(recognizers: [
        PhononRecognizer(),
        WhisperKitRecognizer(modelName: "openai_whisper-base"),
    ])
    private var transcriptionTask: Task<Void, Never>?
    @Published private(set) var activeRuntime: SpeechRuntimeID?

    private var speechEngine: SpeechEnginePreference {
        SettingsService.shared.settings.speechEngine ?? .automatic
    }

    /// Called with the recognizer's text. The handler applies cleanup and insertion, then passes
    /// the same `RecognizedDictation` to `saveToHistory(finalText:from:)`.
    var onTranscriptionComplete: ((RecognizedDictation) -> Void)?

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
    
    init() {}

    func startTranscription(model: String = "base", language: String? = nil) {
        isTranscribing = true
        error = nil
        recognizers.prewarm(speechEngine)
    }

    func stopTranscription() {
        isTranscribing = false
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    func transcribeAudioFile(_ audioURL: URL) async {
        defer { try? FileManager.default.removeItem(at: audioURL) }

        await MainActor.run {
            isTranscribing = true
            transcriptionProgress = 0
            error = nil
            if recognizers.isReady(speechEngine) {
                statusMessage = "Transcribing audio..."
                pipelineStage = .transcribing
            } else {
                statusMessage = "Preparing the speech model locally…"
                pipelineStage = .loadingModel
                isDownloadingModel = true
            }
        }

        print("🎙️ Starting transcription of: \(audioURL.lastPathComponent)")
        let durationMs = Self.audioDurationMilliseconds(audioURL)

        do {
            let result = try await recognizers.transcribe(
                audioURL,
                preference: speechEngine,
                vocabulary: SettingsService.shared.settings.vocabulary ?? [],
                onRuntimeChange: { [weak self] runtime in
                    self?.activeRuntime = runtime
                },
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isTranscribing else { return }
                        self.isDownloadingModel = false
                        self.pipelineStage = .transcribing
                        self.transcriptionProgress = progress
                        self.statusMessage = "Transcribing · ~\(Int(progress * 100))%"
                    }
                }
            )
            isDownloadingModel = false
            for fallback in result.fallbacks {
                print("⚠️ \(fallback.runtime.displayName) unavailable, used \(result.runtime.displayName): \(fallback.error)")
            }
            let recognizedSegments = result.segments
            print("✅ Transcription complete - \(recognizedSegments.count) segments")

            await MainActor.run {
                self.segments = recognizedSegments
                self.statusMessage = "Transcription complete"
                self.isTranscribing = false
                self.transcriptionProgress = nil

                // Get full transcribed text
                let fullText = self.segments.map { $0.text }.joined(separator: " ")
                self.currentText = fullText

                guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.pipelineStage = .noSpeech
                    self.statusMessage = "No speech was detected"
                    return
                }

                // Trigger callback with transcribed text
                self.onTranscriptionComplete?(RecognizedDictation(
                    text: fullText,
                    runtime: result.runtime,
                    durationMs: durationMs
                ))
            }
        } catch {
            print("❌ Transcription error: \(error)")
            await MainActor.run {
                self.isDownloadingModel = false
                self.error = "Transcription failed: \(error.localizedDescription)"
                self.statusMessage = "Transcription failed"
                self.isTranscribing = false
                self.transcriptionProgress = nil
                self.pipelineStage = .error("Transcription failed")
            }
        }
    }

    /// Saves one finished dictation (after cleanup) to the local history when the user has
    /// "Save transcript history" on. Never logs transcript text.
    func saveToHistory(finalText: String, from dictation: RecognizedDictation) {
        guard SettingsService.shared.settings.saveTranscriptHistory ?? true else { return }
        let text = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        TranscriptHistoryModel.shared.save(NewTranscript(
            text: text,
            rawText: dictation.text.trimmingCharacters(in: .whitespacesAndNewlines),
            durationMs: dictation.durationMs,
            runtime: dictation.runtime,
            // Phonon-2 is English-only; Whisper's detected language is not surfaced by the chain.
            language: dictation.runtime == .phonon ? "en" : nil
        ))
    }

    private nonisolated static func audioDurationMilliseconds(_ url: URL) -> Int64? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Int64((Double(file.length) / sampleRate * 1_000).rounded())
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
