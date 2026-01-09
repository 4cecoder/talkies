import SwiftUI
import AVFoundation

struct DictationView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var showHistory = false

    var body: some View {
        ZStack {
            // Animated mesh gradient background (caustics simulation)
            AnimatedMeshGradient()
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .blur(radius: 30)
                .opacity(0.4)

            // Ultra-transparent glassmorphism layer
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.6)
                .clipShape(RoundedRectangle(cornerRadius: 28))

            // Dark tint overlay
            Rectangle()
                .fill(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 28))

            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))

            // Border with shimmer effect
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )

            // Content
            VStack(spacing: 0) {
                if showHistory {
                    TranscriptHistoryView()
                } else {
                    MainDictationContent()
                }
            }
        }
        .frame(width: 520, height: showHistory ? 400 : 140)
        .shadow(color: .black.opacity(0.7), radius: 50, x: 0, y: 25)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

struct MainDictationContent: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var isHoveringButton = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact top bar - fixed height to prevent shifting
            HStack(spacing: 12) {
                // Minimal status
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                        .shadow(color: statusColor.opacity(0.9), radius: 3, x: 0, y: 0)

                    Text(statusText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 0.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Ultra-compact record button
                ZStack {
                    // Glow effect
                    if audioRecorder.isRecording {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.red.opacity(0.5), Color.red.opacity(0.0)],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 18
                                )
                            )
                            .frame(width: 36, height: 36)
                    }

                    // Button
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: audioRecorder.isRecording ?
                                        [Color.red.opacity(0.95), Color.red.opacity(0.75)] :
                                        [Color.white.opacity(0.2), Color.white.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )

                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }
                    .frame(width: 28, height: 28)
                    .shadow(color: audioRecorder.isRecording ? .red.opacity(0.7) : .black.opacity(0.5), radius: 6, x: 0, y: 2)
                }
                .scaleEffect(isHoveringButton ? 1.1 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHoveringButton)
                .onHover { hovering in
                    isHoveringButton = hovering
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Full-width waveform - fixed height
            WaveformView(audioLevel: audioRecorder.audioLevel, isRecording: audioRecorder.isRecording)
                .frame(height: 60)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            // Minimal bottom - fixed height to prevent shifting
            HStack(spacing: 6) {
                // Show pipeline stage with icon when processing
                if transcriptionService.pipelineStage != .idle && transcriptionService.pipelineStage != .recording {
                    Image(systemName: transcriptionService.pipelineStage.icon)
                        .font(.system(size: 8))
                        .foregroundColor(transcriptionService.pipelineStage.color.opacity(0.8))

                    if case .complete = transcriptionService.pipelineStage {
                        // Show transcribed text briefly on completion
                        Text(transcriptionService.currentText.prefix(50) + (transcriptionService.currentText.count > 50 ? "..." : ""))
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        ProgressView()
                            .scaleEffect(0.4)
                            .progressViewStyle(CircularProgressViewStyle(tint: transcriptionService.pipelineStage.color.opacity(0.8)))
                        Text(transcriptionService.pipelineStage.displayText)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else if !transcriptionService.currentText.isEmpty && transcriptionService.pipelineStage == .idle {
                    Text(transcriptionService.currentText.prefix(60) + (transcriptionService.currentText.count > 60 ? "..." : ""))
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                        .foregroundColor(.clear)
                }
            }
            .frame(height: 18)
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
    }

    private var statusColor: Color {
        // Use pipeline stage for more accurate status
        switch transcriptionService.pipelineStage {
        case .recording:
            return .red
        case .transcribing:
            return .orange
        case .enhancingOllama, .enhancingLMStudio:
            return .purple
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

    private var statusText: String {
        // Use pipeline stage for more accurate status
        switch transcriptionService.pipelineStage {
        case .recording:
            return "Recording - \(audioRecorder.formattedDuration)"
        case .transcribing:
            return "Transcribing..."
        case .enhancingOllama:
            return "Enhancing with Ollama..."
        case .enhancingLMStudio:
            return "Enhancing with LM Studio..."
        case .insertingText:
            return "Inserting text..."
        case .complete:
            return "Done!"
        case .error(let msg):
            return "Error: \(msg)"
        case .idle:
            if transcriptionService.isDownloadingModel {
                return "Downloading model..."
            }
            return "Press Right ⌥ to start"
        }
    }

}

struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool

    private let barCount = 60

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: barGradientColors(for: index),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: barWidth(totalWidth: geometry.size.width), height: barHeight(for: index))
                        .shadow(color: barColor(for: index).opacity(0.6), radius: 3, x: 0, y: 0)
                        .animation(.spring(response: 0.12, dampingFraction: 0.75), value: audioLevel)
                        .animation(.easeOut(duration: 0.2), value: isRecording)
                }
            }
        }
    }

    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        let spacing = CGFloat(barCount - 1) * 2
        return (totalWidth - spacing) / CGFloat(barCount)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 4 }

        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        let maxDistance = CGFloat(centerIndex)

        // Create wave pattern with center emphasis
        let centerWeight = 1.0 - (CGFloat(distanceFromCenter) / maxDistance) * 0.5

        // Add slight randomization for more organic feel
        let randomFactor = 1.0 + CGFloat.random(in: -0.1...0.1)

        let normalizedLevel = CGFloat(max(0, min(1, audioLevel + 0.1))) // Boost sensitivity
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 70

        return baseHeight + (maxHeight - baseHeight) * normalizedLevel * centerWeight * randomFactor
    }

    private func barColor(for index: Int) -> Color {
        let normalizedLevel = max(0, min(1, audioLevel))

        if !isRecording {
            return .white.opacity(0.12)
        } else if normalizedLevel > 0.7 {
            return Color(red: 1.0, green: 0.2, blue: 0.3)
        } else if normalizedLevel > 0.4 {
            return Color(red: 1.0, green: 0.5, blue: 0.2)
        } else {
            return Color(red: 0.3, green: 0.95, blue: 0.6)
        }
    }

    private func barGradientColors(for index: Int) -> [Color] {
        let baseColor = barColor(for: index)

        if !isRecording {
            return [baseColor.opacity(0.15), baseColor.opacity(0.08)]
        }

        return [
            baseColor.opacity(0.95),
            baseColor.opacity(0.7),
            baseColor.opacity(0.5)
        ]
    }
}

struct TranscriptHistoryView: View {
    @EnvironmentObject var transcriptionService: TranscriptionService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript History")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

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
