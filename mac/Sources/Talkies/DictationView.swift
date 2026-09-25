import SwiftUI
import AVFoundation
import AppKit
import TalkiesAudio

struct DictationView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var showHistory = false
    let onToggleRecording: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.085))

            Circle()
                .fill(Color(red: 0.46, green: 0.30, blue: 0.95).opacity(0.18))
                .frame(width: 220, height: 150)
                .blur(radius: 38)
                .offset(x: -190, y: -75)

            LinearGradient(
                colors: [Color.white.opacity(0.035), .clear, Color.black.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                if showHistory {
                    TranscriptHistoryView(onClose: { withAnimation(.easeOut(duration: 0.18)) { showHistory = false } })
                } else {
                    MainDictationContent(
                        onToggleRecording: onToggleRecording,
                        onShowHistory: { withAnimation(.easeOut(duration: 0.18)) { showHistory = true } }
                    )
                }
            }
        }
        .frame(width: 560, height: showHistory ? 420 : 184)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 28, x: 0, y: 14)
    }
}

struct MainDictationContent: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var didCopyTranscript = false
    let onToggleRecording: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: 5)

                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(statusColor)
                        .frame(width: 13, height: 13)
                        .accessibilityLabel("Talkies is processing")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(statusHint)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button(action: onShowHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Show recent transcripts")
                .accessibilityLabel("Show transcript history")

                Button(action: onToggleRecording) {
                    Label(
                        audioRecorder.isRecording ? "Stop" : (audioRecorder.hasPermission ? "Dictate" : "Enable mic"),
                        systemImage: audioRecorder.isRecording ? "stop.fill" : "mic.fill"
                    )
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(
                            audioRecorder.isRecording ? Color(red: 0.86, green: 0.24, blue: 0.38) : Color(red: 0.40, green: 0.28, blue: 0.85),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .help(audioRecorder.isRecording ? "Stop dictation" : "Start dictation")
                .accessibilityLabel(audioRecorder.isRecording ? "Stop dictation" : "Start dictation")
                .accessibilityHint(audioRecorder.isRecording ? "Finishes this recording" : "Starts recording with the selected microphone")
            }

            WaveformView(samples: audioRecorder.waveformSamples, isRecording: audioRecorder.isRecording)
                .frame(height: 56)

            HStack(spacing: 7) {
                if transcriptionService.pipelineStage != .idle && transcriptionService.pipelineStage != .recording {
                    Image(systemName: transcriptionService.pipelineStage.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(transcriptionService.pipelineStage.color)
                    Text(bottomStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    if showsCopyAction {
                        Button {
                            TextInserter.shared.copyToClipboard(transcriptionService.currentText)
                            didCopyTranscript = true
                        } label: {
                            Label(didCopyTranscript ? "Copied" : "Copy", systemImage: didCopyTranscript ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.9))
                        .help("Copy the transcript so you can paste it yourself")
                    }
                } else if !transcriptionService.currentText.isEmpty {
                    Text(transcriptionService.currentText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                } else {
                    Text(audioRecorder.hasPermission ? "Hold Right Option for push-to-talk" : "Allow microphone access to start dictating")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                Text("100% on-device")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.64, green: 0.58, blue: 1.0).opacity(0.9))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 17)
        .padding(.bottom, 15)
        .onChange(of: transcriptionService.pipelineStage) { _, stage in
            if stage == .recording { didCopyTranscript = false }
        }
    }

    private var statusColor: Color {
        // Use pipeline stage for more accurate status
        switch transcriptionService.pipelineStage {
        case .loadingModel, .requestingMicrophonePermission:
            return .orange
        case .recording:
            return .red
        case .transcribing:
            return .orange
        case .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini:
            return .purple
        case .cleanupFallback, .clipboardFallback, .noSpeech:
            return .orange
        case .insertingText:
            return .blue
        case .complete:
            return .green
        case .error:
            return .red
        case .idle:
            return transcriptionService.isDownloadingModel ? .yellow : .green
        }
    }

    private var showsProgress: Bool {
        switch transcriptionService.pipelineStage {
        case .loadingModel, .transcribing, .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini, .insertingText:
            return true
        default:
            return false
        }
    }

    private var showsCopyAction: Bool {
        switch transcriptionService.pipelineStage {
        case .complete, .cleanupFallback, .clipboardFallback:
            return !transcriptionService.currentText.isEmpty
        default:
            return false
        }
    }

    private var statusText: String {
        switch transcriptionService.pipelineStage {
        case .loadingModel:
            return "Loading the local speech model"
        case .requestingMicrophonePermission:
            return "Allow microphone access to continue"
        case .recording:
            return "Recording · \(audioRecorder.formattedDuration)"
        case .transcribing:
            return "Transcribing"
        case .enhancingOllama:
            return "Enhancing with Ollama..."
        case .enhancingLMStudio:
            return "Enhancing with LM Studio..."
        case .cleaningS1Mini:
            return "Cleaning with S1-mini..."
        case .cleanupFallback:
            return "Cleanup unavailable · using your raw transcript"
        case .insertingText:
            return "Inserting text..."
        case .complete:
            return "Paste shortcut sent"
        case .clipboardFallback:
            return "Text ready to paste"
        case .noSpeech:
            return "No speech detected"
        case .error(let msg):
            return "Error: \(msg)"
        case .idle:
            if transcriptionService.isDownloadingModel {
                return "Downloading model..."
            }
            return audioRecorder.hasPermission ? "Ready to dictate" : "Microphone access needed"
        }
    }

    private var statusHint: String {
        switch transcriptionService.pipelineStage {
        case .loadingModel:
            return transcriptionService.isDownloadingModel
                ? "Preparing the on-device recognizer. This can take a moment the first time."
                : transcriptionService.statusMessage
        case .requestingMicrophonePermission:
            return "Choose Allow in System Settings, then try again."
        case .recording:
            return "Speak naturally · audio stays on this Mac"
        case .transcribing, .cleaningS1Mini, .enhancingOllama, .enhancingLMStudio:
            return transcriptionService.statusMessage.isEmpty ? "Processing locally on this Mac" : transcriptionService.statusMessage
        case .insertingText:
            return transcriptionService.statusMessage
        case .cleanupFallback:
            return "The original words will be used."
        case .clipboardFallback(let reason):
            return reason
        case .noSpeech:
            return "Try a longer phrase and speak toward your selected microphone."
        case .complete:
            return "If it did not appear in the target field, choose Copy and press ⌘V."
        case .error(let message):
            return message
        case .idle:
            return audioRecorder.hasPermission ? "Hold Right Option or choose Dictate" : "Choose Dictate to allow microphone access"
        }
    }

    private var bottomStatusText: String {
        switch transcriptionService.pipelineStage {
        case .complete, .clipboardFallback:
            return transcriptionService.currentText
        case .error(let message):
            return message
        case .noSpeech:
            return "Speak clearly and try again."
        case .cleanupFallback:
            return transcriptionService.statusMessage.isEmpty ? "Using the uncleaned transcript." : transcriptionService.statusMessage
        default:
            break
        }
        return transcriptionService.pipelineStage.displayText
    }

}

struct WaveformView: View {
    let samples: [Float]
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let barCount = max(1, Int(size.width / 3))
            let gap: CGFloat = 1.1
            let barWidth = max(1, (size.width - CGFloat(barCount - 1) * gap) / CGFloat(barCount))
            let centerY = size.height / 2
            let maxBarHeight = size.height * 0.88
            let palette = isRecording
                ? [Color(red: 1.0, green: 0.35, blue: 0.49), Color(red: 1.0, green: 0.63, blue: 0.47), Color(red: 0.72, green: 0.51, blue: 1.0)]
                : [Color(red: 0.49, green: 0.40, blue: 0.96), Color(red: 0.37, green: 0.76, blue: 0.97)]
            let gradient = Gradient(colors: palette)

            for index in 0..<barCount {
                let lower = min(samples.count - 1, index * samples.count / barCount)
                let upper = max(lower + 1, min(samples.count, (index + 1) * samples.count / barCount))
                let peak = samples.isEmpty ? 0 : samples[lower..<upper].reduce(Float.zero) { max($0, $1.isFinite ? $1 : 0) }
                let normalized = max(0, min(1, (CGFloat(peak) - 0.035) / 0.965))
                let response = pow(normalized, 0.82)
                let height = max(2.5, response * maxBarHeight)
                let x = CGFloat(index) * (barWidth + gap)
                let rect = CGRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
                var barContext = context
                barContext.opacity = isRecording ? 0.96 : 0.7
                barContext.fill(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: x, y: rect.minY),
                        endPoint: CGPoint(x: x, y: rect.maxY)
                    )
                )
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Audio waveform")
        .accessibilityValue(isRecording ? "Live microphone level" : "Recent audio level")
        .accessibilityHint(reduceMotion ? "Shows microphone input without animation" : "Shows recent microphone input")
    }
}

struct TranscriptHistoryView: View {
    @EnvironmentObject var transcriptionService: TranscriptionService
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript History")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close transcript history")

                Button("Clear") {
                    transcriptionService.clearTranscript()
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if transcriptionService.segments.isEmpty {
                        Text("No transcripts yet")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(transcriptionService.segments) { segment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(segment.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                Text(segment.text)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
