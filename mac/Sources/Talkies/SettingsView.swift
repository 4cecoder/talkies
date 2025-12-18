import SwiftUI
import ServiceManagement

// MARK: - Plugin Protocol
/// Protocol for all Talkies plugins (MCP, Ollama, etc.)
@MainActor
protocol TalkiesPlugin: Identifiable, ObservableObject {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var icon: String { get }
    var isEnabled: Bool { get set }

    /// Returns the settings view for this plugin
    @ViewBuilder func settingsView() -> AnyView
}

// MARK: - Plugin Manager
@MainActor
class PluginManager: ObservableObject {
    @Published var plugins: [any TalkiesPlugin] = []

    // Singleton instance for global access
    static let shared = PluginManager()

    init() {
        // Register plugins
        let ollamaPlugin = OllamaPlugin()
        plugins.append(ollamaPlugin)

        let lmStudioPlugin = LMStudioPlugin()
        plugins.append(lmStudioPlugin)

        let sentimentPlugin = SentimentPlugin()
        plugins.append(sentimentPlugin)

        // DISABLED: Conflicts with Kokoro TTS due to duplicate MLX classes
        // let imageGenPlugin = MLXImageGenPlugin()
        // plugins.append(imageGenPlugin)

        // TABLED: Kokoro TTS plugin (requires Xcode for Metal shader compilation)
        // let ttsPlugin = MLXTTSPlugin()
        // plugins.append(ttsPlugin)
    }

    // Get Ollama plugin if enabled
    var ollamaPlugin: OllamaPlugin? {
        plugins.first { $0.id == "ollama" } as? OllamaPlugin
    }

    // Get LM Studio plugin if enabled
    var lmStudioPlugin: LMStudioPlugin? {
        plugins.first { $0.id == "lmstudio" } as? LMStudioPlugin
    }

    // Get Image Generation plugin if enabled
    var imageGenPlugin: MLXImageGenPlugin? {
        plugins.first { $0.id == "mlx-image-gen" } as? MLXImageGenPlugin
    }

    // Get TTS plugin if enabled
    var ttsPlugin: MLXTTSPlugin? {
        plugins.first { $0.id == "mlx-tts" } as? MLXTTSPlugin
    }

    // Get Sentiment plugin if enabled
    var sentimentPlugin: SentimentPlugin? {
        plugins.first { $0.id == "sentiment" } as? SentimentPlugin
    }

    // Get all enabled plugins
    var enabledPlugins: [any TalkiesPlugin] {
        plugins.filter { $0.isEnabled }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var pluginManager = PluginManager.shared
    @State private var selectedItem: SettingsSidebarItem?

    enum SettingsSidebarItem: Hashable, Identifiable {
        case general
        case plugins
        case plugin(id: String)
        case advanced

        var id: String {
            switch self {
            case .general: return "general"
            case .plugins: return "plugins"
            case .plugin(let id): return "plugin-\(id)"
            case .advanced: return "advanced"
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SettingsSidebarItem, rhs: SettingsSidebarItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedItem) {
                // Main sections
                Section {
                    Label("General", systemImage: "gearshape")
                        .tag(SettingsSidebarItem.general)

                    Label("Plugins", systemImage: "puzzlepiece.extension")
                        .tag(SettingsSidebarItem.plugins)
                }

                // Enabled plugins get their own sidebar items
                if !pluginManager.enabledPlugins.isEmpty {
                    Section(header: Text("Enabled Plugins")) {
                        ForEach(pluginManager.enabledPlugins, id: \.id) { plugin in
                            Label(plugin.name, systemImage: plugin.icon)
                                .tag(SettingsSidebarItem.plugin(id: plugin.id))
                        }
                    }
                }

                Section {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                        .tag(SettingsSidebarItem.advanced)
                }
            }
            .navigationTitle("Settings")
            .frame(minWidth: 200)
        } detail: {
            // Detail view
            Group {
                if let selectedItem = selectedItem {
                    switch selectedItem {
                    case .general:
                        GeneralSettingsView()
                    case .plugins:
                        PluginsSettingsView()
                            .environmentObject(pluginManager)
                    case .plugin(let pluginId):
                        if let plugin = pluginManager.plugins.first(where: { $0.id == pluginId }) {
                            plugin.settingsView()
                        } else {
                            Text("Plugin not found")
                        }
                    case .advanced:
                        AdvancedSettingsView()
                    }
                } else {
                    Text("Select a settings category")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedItem == nil {
                selectedItem = .general
            }
        }
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared

    private var threshold: Binding<Double> {
        Binding(
            get: { settingsService.settings.pushToTalkThreshold },
            set: { settingsService.settings.pushToTalkThreshold = $0 }
        )
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { settingsService.settings.launchAtLogin },
            set: { settingsService.settings.launchAtLogin = $0 }
        )
    }

    private var voiceAssistantMode: Binding<Bool> {
        Binding(
            get: { settingsService.settings.voiceAssistantMode },
            set: { settingsService.settings.voiceAssistantMode = $0 }
        )
    }

    private var insertTextInAssistantMode: Binding<Bool> {
        Binding(
            get: { settingsService.settings.insertTextInAssistantMode },
            set: { settingsService.settings.insertTextInAssistantMode = $0 }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Voice Assistant Mode")) {
                Toggle("Enable Voice Assistant", isOn: voiceAssistantMode)
                    .help("Speak responses back using TTS instead of inserting text")

                if settingsService.settings.voiceAssistantMode {
                    Toggle("Also Insert Text", isOn: insertTextInAssistantMode)
                        .help("Insert text at cursor in addition to speaking it")

                    Text("When enabled, Talkies will speak LLM responses instead of just inserting them as text. Perfect for hands-free conversations!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Startup")) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settingsService.settings.launchAtLogin },
                    set: { newValue in
                        settingsService.settings.launchAtLogin = newValue
                        setLaunchAtLogin(enabled: newValue)
                    }
                ))
                .help("Automatically start Talkies when you log in")
            }

            Section(header: Text("Intelligent Detection")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Push-to-Talk Threshold: \(Int(settingsService.settings.pushToTalkThreshold * 1000))ms")
                        .font(.headline)

                    Slider(value: threshold, in: 0.05...0.5, step: 0.05) {
                        Text("Threshold")
                    }

                    Text("Hold the key longer than this to activate push-to-talk mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(header: Text("Keyboard Shortcut")) {
                HStack {
                    Text("Activation Key:")
                    Spacer()
                    Text("Right Option (⌥)")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("About")) {
                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Transcription:")
                    Spacer()
                    Text("WhisperKit (Native)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

// MARK: - Plugins Settings
struct PluginsSettingsView: View {
    @EnvironmentObject var pluginManager: PluginManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Plugins")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enable plugins to add new capabilities to Talkies. Enabled plugins will appear in the sidebar for easy access to their settings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top)

                // Plugin list
                VStack(spacing: 12) {
                    ForEach(pluginManager.plugins, id: \.id) { plugin in
                        PluginCard(plugin: plugin)
                            .environmentObject(pluginManager)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Plugins")
    }
}

struct PluginCard: View {
    let plugin: any TalkiesPlugin
    @EnvironmentObject var pluginManager: PluginManager

    var body: some View {
        HStack(spacing: 16) {
            // Plugin icon
            Image(systemName: plugin.icon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

            // Plugin info
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.headline)

                Text(plugin.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Toggle switch
            Toggle("", isOn: Binding(
                get: { plugin.isEnabled },
                set: { newValue in
                    withAnimation {
                        // Handle LLM mutual exclusivity: only one of Ollama/LM Studio can be active
                        if newValue {
                            if plugin.id == "ollama" {
                                // Disable LM Studio when enabling Ollama
                                pluginManager.lmStudioPlugin?.isEnabled = false
                            } else if plugin.id == "lmstudio" {
                                // Disable Ollama when enabling LM Studio
                                pluginManager.ollamaPlugin?.isEnabled = false
                            }
                        }

                        // Set the plugin's enabled state
                        if let ollamaPlugin = plugin as? OllamaPlugin {
                            ollamaPlugin.isEnabled = newValue
                        } else if let lmStudioPlugin = plugin as? LMStudioPlugin {
                            lmStudioPlugin.isEnabled = newValue
                        } else if let imageGenPlugin = plugin as? MLXImageGenPlugin {
                            imageGenPlugin.isEnabled = newValue
                        } else if let ttsPlugin = plugin as? MLXTTSPlugin {
                            ttsPlugin.isEnabled = newValue
                        } else if let sentimentPlugin = plugin as? SentimentPlugin {
                            sentimentPlugin.isEnabled = newValue
                        }

                        // Force PluginManager to notify observers for sidebar refresh
                        pluginManager.objectWillChange.send()
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Advanced Settings
struct AdvancedSettingsView: View {
    @ObservedObject private var settingsService = SettingsService.shared

    private var debugMode: Binding<Bool> {
        Binding(
            get: { settingsService.settings.debugMode },
            set: { settingsService.settings.debugMode = $0 }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Debug")) {
                Toggle("Enable Debug Logging", isOn: debugMode)
                    .help("Show detailed logs in console")
            }

            Section(header: Text("Configuration")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Config File:")
                        Spacer()
                        Text("~/.talkies/config.json")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Button("Open Config Directory") {
                        let configDir = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".talkies")
                        NSWorkspace.shared.open(configDir)
                    }
                    .buttonStyle(.bordered)

                    Text("Settings are automatically saved to a JSON file for easy debugging and portability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Performance")) {
                HStack {
                    Text("Window Rendering:")
                    Spacer()
                    Text("Optimized")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Audio Engine:")
                    Spacer()
                    Text("AVFoundation")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Privacy")) {
                HStack {
                    Text("On-Device Processing:")
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.green)
                }

                Text("All transcription happens locally on your device. No data is sent to external servers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Advanced")
    }
}

// MARK: - Helper Functions
func setLaunchAtLogin(enabled: Bool) {
    do {
        if enabled {
            try SMAppService.mainApp.register()
            print("✅ Successfully enabled launch at login")
        } else {
            try SMAppService.mainApp.unregister()
            print("✅ Successfully disabled launch at login")
        }
    } catch {
        print("⚠️ Failed to set launch at login: \(error.localizedDescription)")
    }
}

// MARK: - Previews
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .frame(width: 600, height: 500)
    }
}
