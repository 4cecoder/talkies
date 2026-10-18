import SwiftUI
import TalkiesConnectors
import TalkiesCore

/// Settings → Agents: the agent hotkey, spoken replies, and cmux socket access.
struct AgentSettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared
    @State private var password = ""
    @State private var hasSavedPassword = CmuxSocketPassword.read() != nil
    @State private var passwordStatus: String?
    @State private var connectionStatus: String?
    @State private var isTesting = false

    private var agentMode: AgentModeSettings { settingsService.settings.agentMode ?? AgentModeSettings() }
    private var dictationKey: ActivationKey { settingsService.settings.activationKey ?? .rightOption }

    private func binding<Value>(_ keyPath: WritableKeyPath<AgentModeSettings, Value>) -> Binding<Value> {
        Binding(
            get: { agentMode[keyPath: keyPath] },
            set: { value in
                var updated = agentMode
                updated[keyPath: keyPath] = value
                settingsService.settings.agentMode = updated
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Agent Mode")) {
                Toggle("Enable agent mode", isOn: binding(\.isEnabled))
                Picker("Agent key", selection: binding(\.hotkey)) {
                    ForEach(AgentHotkey.allCases) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .disabled(!agentMode.isEnabled)
                if agentMode.hotkey.conflicts(with: dictationKey) {
                    Label("This is also the dictation key. Choose a different agent key.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Toggle("Speak status replies", isOn: binding(\.speakReplies))
                    .disabled(!agentMode.isEnabled)
                Text("""
                    Hold the agent key and start with an agent's name: “Atlas, run the tests” or “What's Atlas doing?”. \
                    The dictation key is unchanged and never runs commands. Prompts wait two seconds so you can cancel \
                    with Esc. Approvals aren't available by voice. Replies are spoken with the on-device macOS voice.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("cmux")) {
                HStack {
                    Text("Command-line tool")
                    Spacer()
                    Text(CmuxExecutableLocator.locate()?.path ?? "Not found")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                SecureField("Socket password", text: $password, prompt: Text(hasSavedPassword ? "Saved in Keychain" : "Optional"))
                HStack {
                    Button("Save Password") { savePassword() }
                        .disabled(password.isEmpty)
                    Button("Remove") { removePassword() }
                        .disabled(!hasSavedPassword)
                    Spacer()
                    if let passwordStatus {
                        Text(passwordStatus).font(.caption).foregroundColor(.secondary)
                    }
                }
                Text("""
                    cmux normally accepts commands only from programs started inside cmux. To use agent mode, open \
                    cmux Settings → Automation and choose Password mode, then save the same password here; it is kept \
                    in your Keychain and passed to cmux through its environment, never on a command line. Automation \
                    mode also works without a password.
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Button(isTesting ? "Testing…" : "Test Connection") { testConnection() }
                        .disabled(isTesting)
                    Spacer()
                }
                if let connectionStatus {
                    Text(connectionStatus)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Agents")
    }

    private func savePassword() {
        do {
            try CmuxSocketPassword.save(password)
            password = ""
            hasSavedPassword = true
            passwordStatus = "Saved in Keychain"
        } catch {
            passwordStatus = error.localizedDescription
        }
    }

    private func removePassword() {
        CmuxSocketPassword.delete()
        hasSavedPassword = false
        passwordStatus = "Removed"
    }

    private func testConnection() {
        isTesting = true
        connectionStatus = nil
        Task {
            // Read-only: lists workspaces and agents, never sends anything.
            let connector = CmuxConnector(socketPassword: { CmuxSocketPassword.read() })
            do {
                let agents = try await connector.list()
                connectionStatus = "Connected. \(AgentStatusSentence.list(agents))"
            } catch {
                connectionStatus = error.localizedDescription
            }
            isTesting = false
        }
    }
}
