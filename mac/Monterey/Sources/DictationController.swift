import AppKit
import Combine
import Foundation

@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var isWorking = false
    @Published private(set) var status = "Ready"
    @Published private(set) var transcript = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var didCopy = false

    let capture = AudioCapture()
    private let modelStore: LocalModelStore?
    private var copyFeedbackTask: Task<Void, Never>?

    init() {
        do {
            modelStore = try LocalModelStore()
        } catch {
            modelStore = nil
            errorMessage = error.localizedDescription
        }
    }

    var elapsedDescription: String {
        let seconds = Int(capture.elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func startRecording() {
        guard !isWorking else { return }
        errorMessage = nil
        status = "Requesting microphone…"
        isWorking = true
        Task {
            do {
                try await capture.start()
                transcript = ""
                status = "Listening"
            } catch {
                status = "Microphone unavailable"
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func stopRecording(cleanupEnabled: Bool) {
        do {
            let audioURL = try capture.stop()
            isWorking = true
            errorMessage = nil
            status = cleanupEnabled ? "Preparing local models…" : "Preparing speech model…"
            let modelStore = self.modelStore
            Task {
                do {
                    guard let modelStore else { throw LocalModelStore.ModelStoreError.storageUnavailable }
                    let whisperModel = try await modelStore.ensure(LocalInference.speechModel)
                    status = "Transcribing on this Mac…"
                    var result = try await Task.detached(priority: .userInitiated) {
                        try LocalInference.transcribe(audioURL: audioURL, modelURL: whisperModel)
                    }.value
                    if cleanupEnabled {
                        status = "Preparing S1-mini cleanup…"
                        let s1MiniModel = try await modelStore.ensure(.s1Mini)
                        status = "Polishing locally…"
                        result = try await Task.detached(priority: .userInitiated) {
                            try LocalInference.clean(result, modelURL: s1MiniModel, options: TranscriptCleanupOptions())
                        }.value
                    }
                    transcript = result
                    status = "Done"
                } catch {
                    status = "Needs attention"
                    errorMessage = error.localizedDescription
                }
                isWorking = false
                try? FileManager.default.removeItem(at: audioURL)
            }
        } catch {
            status = "Could not stop recording"
            errorMessage = error.localizedDescription
        }
    }

    func copyTranscript() {
        guard !transcript.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        didCopy = pasteboard.setString(transcript, forType: .string)
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            didCopy = false
        }
    }
}
