import SwiftUI
import AppKit
import TalkiesAudio
import TalkiesCore

/// Agent-mode content of the floating HUD: target picker, the tier-1 cancel window,
/// "Which agent?" choices, and status replies.
struct AgentPanelView: View {
    @ObservedObject var controller: AgentModeController
    @EnvironmentObject private var audioRecorder: AudioRecorder
    @EnvironmentObject private var transcriptionService: TranscriptionService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.62, green: 0.55, blue: 1.0))
                Text("Agent mode")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 6)
                AgentTargetPicker(controller: controller)
                Button {
                    controller.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close agent mode")
                .accessibilityLabel("Close agent mode")
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .idle, .listening:
            VStack(alignment: .leading, spacing: 8) {
                WaveformView(samples: audioRecorder.waveformSamples, isRecording: audioRecorder.isRecording, stage: transcriptionService.pipelineStage)
                    .frame(height: 40)
                Text(listeningHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
            }
        case .working(let message):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(.white)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxHeight: .infinity)
        case .pending(let pending):
            PendingSendView(pending: pending, controller: controller)
        case .choosing(let candidates, _):
            VStack(alignment: .leading, spacing: 8) {
                Text("Which agent?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(candidates) { agent in
                            Button {
                                controller.select(agent)
                            } label: {
                                Text(label(for: agent))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .frame(height: 28)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Choose \(agent.name)")
                        }
                    }
                }
                Text("Talkies never guesses between agents with similar names.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .notice(let notice):
            NoticeView(notice: notice)
        }
    }

    private var listeningHint: String {
        guard let keyName = controller.agentKeyName else {
            return "Choose an agent key in Settings → Agents, then hold it while you speak."
        }
        if audioRecorder.isRecording {
            return "Listening… say a name first, like “Atlas, run the tests”, or ask “What's Atlas doing?”"
        }
        if let target = controller.selectedTarget {
            return "Hold \(keyName) to talk to \(target.name), or start with another agent's name."
        }
        return "Hold \(keyName) while you speak, and start with an agent's name."
    }

    private func label(for agent: AgentRef) -> String {
        let number = controller.number(of: agent).map { "\($0). " } ?? ""
        let workspace = agent.workspace.flatMap { $0 == agent.name ? nil : " · \($0)" } ?? ""
        return number + agent.name + workspace
    }
}

private struct PendingSendView: View {
    let pending: AgentModeController.PendingAction
    @ObservedObject var controller: AgentModeController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                if case .prompt(let text) = pending.kind {
                    Text("“\(text)”")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            if pending.isHeld {
                Text(pending.note ?? "Waiting for you. Say “cancel” or “send”, or use the buttons.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView(timerInterval: pending.startedAt...pending.deadline, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(Color(red: 0.62, green: 0.55, blue: 1.0))
                    .accessibilityLabel("Sends in two seconds unless cancelled")
            }
            HStack(spacing: 8) {
                Button {
                    controller.cancelPending()
                } label: {
                    Label("Cancel  esc", systemImage: "xmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel. Nothing is sent.")
                Button {
                    Task { await controller.firePendingNow() }
                } label: {
                    Label(pending.kind == .show ? "Show now" : "Send now", systemImage: "paperplane")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var title: String {
        switch pending.kind {
        case .prompt: "To \(pending.agent.name):"
        case .show: "Show \(pending.agent.name) in cmux"
        }
    }
}

private struct NoticeView: View {
    let notice: AgentModeController.Notice

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.top, 1)
                ScrollView {
                    Text(notice.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 74)
            }
            if notice.needsSocketSetup {
                HStack(spacing: 8) {
                    Button("Open cmux") { AgentModeController.openCmux() }
                    Button("Talkies Settings…") { NSApp.sendAction(#selector(AppDelegate.showSettings), to: nil, from: nil) }
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
    }

    private var icon: String {
        switch notice.tone {
        case .info: "text.bubble"
        case .success: "checkmark.circle.fill"
        case .warning: "hand.raised.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch notice.tone {
        case .info: .cyan
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}

/// Lists cmux workspaces and their agents; the selection is the target for unaddressed prompts.
struct AgentTargetPicker: View {
    @ObservedObject var controller: AgentModeController

    var body: some View {
        Menu {
            if controller.agents.isEmpty {
                Text(controller.lastListError ?? "No cmux agents found")
            }
            ForEach(workspaces, id: \.self) { workspace in
                Section(workspace) {
                    ForEach(controller.agents.filter { ($0.workspace ?? "") == workspace }) { agent in
                        Button {
                            controller.select(agent)
                        } label: {
                            let number = controller.number(of: agent).map { "\($0). " } ?? ""
                            if agent.id == controller.selectedTargetID {
                                Label("\(number)\(agent.name) · \(agent.status.spokenPhrase)", systemImage: "checkmark")
                            } else {
                                Text("\(number)\(agent.name) · \(agent.status.spokenPhrase)")
                            }
                        }
                    }
                }
            }
            Divider()
            Button("Refresh agents") { Task { await controller.refreshAgents() } }
        } label: {
            Label(controller.selectedTarget?.name ?? "Choose agent", systemImage: "scope")
                .font(.system(size: 11, weight: .semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(.white)
        .help("Target for prompts that don't start with an agent's name")
        .accessibilityLabel("Agent target: \(controller.selectedTarget?.name ?? "none")")
        .task { if controller.agents.isEmpty { await controller.refreshAgents() } }
    }

    private var workspaces: [String] {
        var seen = Set<String>()
        return controller.agents.compactMap { agent in
            let workspace = agent.workspace ?? ""
            return seen.insert(workspace).inserted ? workspace : nil
        }
    }
}
