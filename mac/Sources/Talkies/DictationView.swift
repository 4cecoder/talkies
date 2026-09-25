import SwiftUI
import AVFoundation
import AppKit
import TalkiesAudio
import TalkiesAccessibility

struct DictationView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @ObservedObject private var settingsService = SettingsService.shared
    @State private var showHistory = false
    @Binding var isCollapsed: Bool
    let onToggleRecording: () -> Void
    let onResize: (CGSize) -> Void

    private var isMini: Bool { settingsService.settings.useMinimalDictationWindow ?? false }
    private var panelSize: CGSize {
        if isCollapsed { return CGSize(width: 124, height: 38) }
        return CGSize(width: isMini ? 360 : 560, height: showHistory ? 420 : (isMini ? 126 : 184))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.055, green: 0.055, blue: 0.085).opacity(0.58))

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
                if isCollapsed {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { isCollapsed = false }
                    } label: {
                        WaveformView(samples: audioRecorder.waveformSamples, isRecording: audioRecorder.isRecording, stage: transcriptionService.pipelineStage)
                            .frame(width: 94, height: 24)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 7)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Open Talkies dictation")
                    .accessibilityLabel("Open Talkies dictation. \(transcriptionService.pipelineStage.displayText)")
                } else if showHistory {
                    TranscriptHistoryView(onClose: { withAnimation(.easeOut(duration: 0.18)) { showHistory = false } })
                } else if isMini {
                    MiniDictationContent(
                        onToggleRecording: onToggleRecording,
                        onShowHistory: { withAnimation(.easeOut(duration: 0.18)) { showHistory = true } }
                    )
                } else {
                    MainDictationContent(
                        onToggleRecording: onToggleRecording,
                        onShowHistory: { withAnimation(.easeOut(duration: 0.18)) { showHistory = true } }
                    )
                }
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .modifier(AvailableLiquidGlass())
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 28, x: 0, y: 14)
        .onChange(of: panelSize) { _, size in onResize(size) }
        .onChange(of: isCollapsed) { _, collapsed in
            if collapsed { showHistory = false }
        }
    }
}

private struct MiniDictationContent: View {
    @EnvironmentObject private var audioRecorder: AudioRecorder
    @EnvironmentObject private var transcriptionService: TranscriptionService
    @State private var didCopyTranscript = false
    let onToggleRecording: () -> Void
    let onShowHistory: () -> Void

    private var stage: PipelineStage { transcriptionService.pipelineStage }
    private var isBusy: Bool {
        switch stage {
        case .loadingModel, .transcribing, .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini, .insertingText: return true
        default: return false
        }
    }
    private var canCopy: Bool {
        switch stage {
        case .complete, .cleanupFallback, .clipboardFallback: return !transcriptionService.currentText.isEmpty
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Circle().fill(stage.color).frame(width: 7, height: 7)
                if isBusy {
                    ProgressView().controlSize(.mini).tint(stage.color).frame(width: 12, height: 12)
                }
                Text(stage.displayText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Button(action: onShowHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show transcript history")
                Button(action: onToggleRecording) {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(audioRecorder.isRecording ? Color.red.opacity(0.85) : Color(red: 0.40, green: 0.28, blue: 0.85), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(audioRecorder.isRecording ? "Stop dictation" : "Start dictation")
            }

            WaveformView(samples: audioRecorder.waveformSamples, isRecording: audioRecorder.isRecording, stage: stage)
                .frame(height: 36)

            HStack(spacing: 7) {
                Text(miniHint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if canCopy {
                    if needsAccessibilityApproval {
                        Button {
                            TextInserter.shared.requestAccessibilityPermissions()
                        } label: {
                            Label("Allow", systemImage: "hand.raised")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                        }
                        .buttonStyle(.plain)
                        .help("Open macOS Accessibility permission settings")
                    }
                    Button {
                        showCopyFeedback(TextInserter.shared.copyToClipboard(transcriptionService.currentText))
                    } label: {
                        Label(didCopyTranscript ? "Copied" : "Copy", systemImage: didCopyTranscript ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(didCopyTranscript ? Color(red: 0.62, green: 1.0, blue: 0.73) : .white)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(didCopyTranscript ? Color.green.opacity(0.25) : Color.white.opacity(0.10), in: Capsule())
                            .overlay(Capsule().stroke(didCopyTranscript ? Color.green.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
                            .scaleEffect(didCopyTranscript ? 1.05 : 1)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(didCopyTranscript ? "Transcript copied. Press Command V to paste." : "Copy transcript")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onChange(of: stage) { _, newStage in if newStage == .recording { didCopyTranscript = false } }
    }

    private var miniHint: String {
        switch stage {
        case .idle:
            return audioRecorder.hasPermission ? "Hold Right Option to dictate" : "Allow microphone access to dictate"
        case .requestingMicrophonePermission, .clipboardFallback, .noSpeech, .error:
            return transcriptionService.statusMessage.isEmpty ? stage.displayText : transcriptionService.statusMessage
        case .transcribing:
            return transcriptionService.statusMessage
        case .cleanupFallback:
            return transcriptionService.statusMessage
        case .complete:
            return "Text inserted · Copy if it didn’t appear"
        default:
            return ""
        }
    }

    private var needsAccessibilityApproval: Bool {
        guard case .clipboardFallback(let reason) = stage else { return false }
        return reason.localizedCaseInsensitiveContains("accessibility")
    }

    private func showCopyFeedback(_ succeeded: Bool) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.68)) { didCopyTranscript = succeeded }
        guard succeeded else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.35)) { didCopyTranscript = false }
        }
    }
}

private struct AvailableLiquidGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.tint(Color(red: 0.43, green: 0.31, blue: 0.92).opacity(0.18)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
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
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            audioRecorder.isRecording ? Color(red: 0.88, green: 0.26, blue: 0.38) : Color(red: 0.22, green: 0.70, blue: 0.43),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .help(audioRecorder.isRecording ? "Stop dictation" : "Start dictation")
                .accessibilityLabel(audioRecorder.isRecording ? "Stop dictation" : (audioRecorder.hasPermission ? "Start dictation" : "Enable microphone"))
                .accessibilityHint(audioRecorder.isRecording ? "Finishes this recording" : "Starts recording with the selected microphone")
            }

            WaveformView(samples: audioRecorder.waveformSamples, isRecording: audioRecorder.isRecording, stage: transcriptionService.pipelineStage)
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
                        if needsAccessibilityApproval {
                            Button {
                                TextInserter.shared.requestAccessibilityPermissions()
                            } label: {
                                Label("Allow access", systemImage: "hand.raised")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.9))
                            .help("Open macOS Accessibility permission settings")
                        }
                        Button {
                            let copied = TextInserter.shared.copyToClipboard(transcriptionService.currentText)
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                                didCopyTranscript = copied
                            }
                        } label: {
                            Label(didCopyTranscript ? "Copied" : "Copy text", systemImage: didCopyTranscript ? "checkmark" : "doc.on.clipboard")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(didCopyTranscript ? Color(red: 0.62, green: 1.0, blue: 0.73) : .white)
                                .padding(.horizontal, 11)
                                .frame(height: 32)
                                .background(didCopyTranscript ? Color.green.opacity(0.25) : Color.white.opacity(0.10), in: Capsule())
                                .overlay(Capsule().stroke(didCopyTranscript ? Color.green.opacity(0.55) : Color.white.opacity(0.12), lineWidth: 1))
                                .scaleEffect(didCopyTranscript ? 1.04 : 1)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .help(didCopyTranscript ? "Transcript copied. Press Command-V in the target field." : "Copy transcript to clipboard")
                        .accessibilityLabel(didCopyTranscript ? "Transcript copied. Press Command V to paste." : "Copy transcript")
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

            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 17)
        .padding(.bottom, 15)
        .onChange(of: transcriptionService.pipelineStage) { _, stage in
            if stage == .recording { didCopyTranscript = false }
        }
    }

    private func showCopyFeedback(_ succeeded: Bool) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.68)) { didCopyTranscript = succeeded }
        guard succeeded else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.35)) { didCopyTranscript = false }
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

    private var needsAccessibilityApproval: Bool {
        guard case .clipboardFallback(let reason) = transcriptionService.pipelineStage else { return false }
        return reason.localizedCaseInsensitiveContains("accessibility")
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
            if let progress = transcriptionService.transcriptionProgress {
                return "Transcribing · ~\(Int(progress * 100))%"
            }
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
            return "Text insertion complete"
        case .clipboardFallback:
            return "Copy transcript to paste manually"
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
    let stage: PipelineStage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animatesWaveform: Bool {
        switch stage {
        case .loadingModel, .transcribing, .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini, .insertingText:
            return true
        default:
            return false
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animatesWaveform || reduceMotion)) { timeline in
            Canvas(rendersAsynchronously: true) { context, size in
                guard size.width > 0, size.height > 0 else { return }

                let barCount = max(1, Int(size.width / 3))
                let gap: CGFloat = 1.1
                let barWidth = max(1, (size.width - CGFloat(barCount - 1) * gap) / CGFloat(barCount))
                let centerY = size.height / 2
                let maxBarHeight = size.height * 0.88
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let gradient = Gradient(colors: palette)

                for index in 0..<barCount {
                    let position = Double(index) / Double(max(barCount - 1, 1))
                    let peak: CGFloat
                    if isRecording {
                        let lower = min(max(samples.count - 1, 0), index * samples.count / barCount)
                        let upper = max(lower + 1, min(samples.count, (index + 1) * samples.count / barCount))
                        peak = samples.isEmpty ? 0 : CGFloat(samples[lower..<upper].reduce(Float.zero) { max($0, $1.isFinite ? $1 : 0) })
                    } else {
                        peak = stateLevel(at: position, phase: phase)
                    }

                    let normalized = max(0, min(1, (peak - 0.035) / 0.965))
                    let response = pow(normalized, 0.82)
                    let height = max(2.5, response * maxBarHeight)
                    let x = CGFloat(index) * (barWidth + gap)
                    let rect = CGRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
                    let path = Path(roundedRect: rect, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
                    var barContext = context
                    barContext.opacity = isRecording ? 0.96 : 0.82
                    barContext.fill(path, with: .linearGradient(gradient, startPoint: CGPoint(x: x, y: rect.minY), endPoint: CGPoint(x: x, y: rect.maxY)))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(stage.displayText)
        .accessibilityValue(isRecording ? "Live microphone level" : animatesWaveform ? "Processing animation" : "Ready")
        .accessibilityHint(reduceMotion ? "Shows Talkies state without animation" : "Waveform shape and color indicate Talkies state")
    }

    private var palette: [Color] {
        if isRecording { return [Color(red: 1.0, green: 0.35, blue: 0.49), Color(red: 1.0, green: 0.63, blue: 0.47), Color(red: 0.72, green: 0.51, blue: 1.0)] }
        switch stage {
        case .loadingModel: return [.blue, .cyan]
        case .transcribing: return [.orange, .yellow]
        case .cleaningS1Mini, .enhancingOllama, .enhancingLMStudio: return [.purple, .pink]
        case .insertingText: return [.cyan, .blue]
        case .complete: return [.green, .mint]
        case .error: return [.red, .orange]
        case .clipboardFallback, .cleanupFallback, .noSpeech, .requestingMicrophonePermission: return [.orange, .yellow]
        case .recording: return [.red, .pink]
        case .idle: return [.purple, .cyan]
        }
    }

    private func stateLevel(at position: Double, phase: Double) -> CGFloat {
        switch stage {
        case .loadingModel:
            return CGFloat(0.12 + 0.22 * (0.5 + 0.5 * sin(phase * 2.2 + position * 3)))
        case .transcribing:
            let sweep = abs(position - (phase * 0.24).truncatingRemainder(dividingBy: 1))
            return CGFloat(0.12 + 0.62 * exp(-sweep * 11))
        case .cleaningS1Mini, .enhancingOllama, .enhancingLMStudio:
            return CGFloat(0.10 + 0.58 * abs(sin(position * 11 - phase * 3.1)))
        case .insertingText:
            let sweep = abs(position - (phase * 0.6).truncatingRemainder(dividingBy: 1))
            return CGFloat(0.12 + 0.74 * exp(-sweep * 15))
        case .complete:
            return CGFloat(0.10 + 0.28 * abs(sin(position * 8)))
        case .error:
            return CGFloat(0.08 + 0.14 * (0.5 + 0.5 * sin(phase * 1.8)))
        default:
            return 0.08
        }
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
