import SwiftUI
import Foundation
import Combine
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

    private let recognizer = WhisperKitRecognizer(modelName: "openai_whisper-base")
    private var transcriptionTask: Task<Void, Never>?
    private var modelInitializationTask: Task<Void, Never>?
    private var modelInitializationError: Error?
    private var isInitialized = false

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
    
    init() {}

    private func beginModelInitializationIfNeeded() {
        guard !isInitialized, modelInitializationTask == nil else { return }
        isDownloadingModel = true
        modelInitializationError = nil
        print("📥 Preparing local WhisperKit recognizer on first use")

        modelInitializationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.recognizer.initialize()
                self.isInitialized = true
                self.modelInitializationError = nil
                self.error = nil
                print("✅ WhisperKit initialized successfully")
            } catch {
                self.modelInitializationError = error
                self.error = "Failed to initialize: \(error.localizedDescription)"
                print("❌ WhisperKit initialization error: \(error)")
            }
            self.isDownloadingModel = false
        }
    }

    private func ensureModelInitialized() async throws {
        if isInitialized && recognizer.isReady { return }
        beginModelInitializationIfNeeded()
        if let modelInitializationTask {
            await modelInitializationTask.value
        }
        if let modelInitializationError {
            throw modelInitializationError
        }
        guard isInitialized && recognizer.isReady else {
            throw WhisperKitRecognizerError.notInitialized
        }
    }

    func startTranscription(model: String = "base", language: String? = nil) {
        print("      TranscriptionService.startTranscription() - START")
        print("         isInitialized: \(isInitialized)")
        print("         recognizer ready: \(recognizer.isReady)")

        if !isInitialized, modelInitializationError != nil {
            modelInitializationTask = nil
            modelInitializationError = nil
        }

        isTranscribing = true
        error = nil
        beginModelInitializationIfNeeded()
        print("      TranscriptionService.startTranscription() - DONE")
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
            if recognizer.isReady {
                statusMessage = "Transcribing audio..."
                pipelineStage = .transcribing
            } else {
                statusMessage = "Preparing the speech model locally…"
                pipelineStage = .loadingModel
            }
        }

        print("🎙️ Starting transcription of: \(audioURL.lastPathComponent)")

        do {
            try await ensureModelInitialized()
            isDownloadingModel = false
            statusMessage = "Transcribing audio..."
            pipelineStage = .transcribing

            let recognizedSegments = try await recognizer.transcribe(
                audioURL,
                deleteAudioAfterProcessing: true,
                vocabulary: SettingsService.shared.settings.vocabulary ?? [],
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isTranscribing else { return }
                        self.transcriptionProgress = progress
                        self.statusMessage = "Transcribing · ~\(Int(progress * 100))%"
                    }
                }
            )
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
                self.onTranscriptionComplete?(fullText)
            }
        } catch {
            print("❌ Transcription error: \(error)")
            await MainActor.run {
                self.error = "Transcription failed: \(error.localizedDescription)"
                self.statusMessage = "Transcription failed"
                self.isTranscribing = false
                self.transcriptionProgress = nil
                self.pipelineStage = .error("Transcription failed")
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
