import SwiftUI
import AVFoundation
import AppKit

@main
struct TalkiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    var settingsWindow: NSWindow?
    var audioRecorder = AudioRecorder()
    var transcriptionService = TranscriptionService()
    var eventMonitor: Any?
    var localEventMonitor: Any?
    var rightOptionKeyWasPressed = false

    // Intelligent mode detection
    var keyPressStartTime: Date?
    var isPushToTalkMode = false
    var isWaitingForRelease = false
    let pushToTalkThreshold: TimeInterval = 0.15 // 150ms threshold

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Crash Logger
        CrashLogger.shared.setup()
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Talkies")

            // Handle left and right clicks differently
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
        }

        // Create menu for right-click (but don't set it yet)
        setupStatusBarMenu()

        // Setup transcription completion callback
        transcriptionService.onTranscriptionComplete = { [weak self] text in
            // Process through LLM if enabled
            Task {
                let finalText: String
                if let ollamaPlugin = PluginManager.shared.ollamaPlugin,
                   ollamaPlugin.isEnabled {
                    do {
                        print("🧠 Processing text through Ollama...")
                        finalText = try await ollamaPlugin.enhanceText(text)
                        print("✅ Enhanced text: \(finalText)")
                    } catch {
                        print("⚠️ Ollama enhancement failed: \(error.localizedDescription)")
                        finalText = text // Fallback to original
                    }
                } else {
                    finalText = text
                }

                await MainActor.run {
                    let voiceAssistantMode = UserDefaults.standard.bool(forKey: "voiceAssistantMode")
                    let insertTextInAssistantMode = UserDefaults.standard.bool(forKey: "insertTextInAssistantMode")

                    // Voice Assistant Mode: Speak the response
                    if voiceAssistantMode {
                        print("🔊 Voice Assistant Mode: Speaking response...")

                        // Speak using TTS
                        if let ttsPlugin = PluginManager.shared.ttsPlugin, ttsPlugin.isEnabled {
                            Task {
                                do {
                                    let audioURL = try await ttsPlugin.synthesizeSpeech(text: finalText)
                                    await MainActor.run {
                                        ttsPlugin.playAudio(url: audioURL)
                                        print("🔊 Playing audio response")
                                    }
                                } catch {
                                    print("⚠️ TTS failed: \(error.localizedDescription)")
                                    // Fallback: insert text if TTS fails
                                    TextInserter.shared.insertTextAtCursor(finalText)
                                }
                            }
                        } else {
                            // TTS not enabled, use native speech
                            let synthesizer = NSSpeechSynthesizer()
                            synthesizer.startSpeaking(finalText)
                        }

                        // Optionally also insert text
                        if insertTextInAssistantMode {
                            TextInserter.shared.insertTextAtCursor(finalText)
                        }
                    } else {
                        // Normal Mode: Insert text at cursor
                        TextInserter.shared.insertTextAtCursor(finalText)
                    }

                    // Auto-hide window after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.hideWindow()
                    }
                }
            }
        }

        // Request accessibility permissions only if not already granted
        if !TextInserter.shared.checkAccessibilityPermissions() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                TextInserter.shared.requestAccessibilityPermissions()
            }
        }

        // Setup global keyboard shortcut (Cmd+Shift+Space)
        setupKeyboardShortcut()

        // Hide dock icon and make menu bar only
        NSApp.setActivationPolicy(.accessory)
    }

    func setupStatusBarMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Talkies", action: #selector(showWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Talkies", action: #selector(quitApp), keyEquivalent: "q"))

        // Set target for menu items
        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
    }

    @objc func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Right-click shows menu
        if event.type == .rightMouseUp {
            statusItem?.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.frame.height + 5), in: sender)
        }
        // Left-click toggles window
        else {
            toggleWindow()
        }
    }

    @objc func showWindowFromMenu() {
        if floatingWindow == nil || floatingWindow?.isVisible == false {
            showWindow()
        }
    }

    @objc func toggleWindow() {
        if let window = floatingWindow, window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

@MainActor
    func showWindow() {
        if floatingWindow == nil {
            // Create floating window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 140),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.hasShadow = false // Disable window shadow, we have custom shadows in SwiftUI
            window.isMovableByWindowBackground = true

            // CRITICAL: Don't steal focus from other apps
            window.ignoresMouseEvents = false // We want to interact with it
            window.hidesOnDeactivate = false

            // Set rounded corners for the window itself
            if let contentView = window.contentView {
                contentView.wantsLayer = true
                contentView.layer?.cornerRadius = 28
                contentView.layer?.masksToBounds = true
            }

            // Set content view
            let contentView = DictationView()
                .environmentObject(audioRecorder)
                .environmentObject(transcriptionService)

            let hostingView = NSHostingView(rootView: contentView)
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 28
            hostingView.layer?.masksToBounds = true

            window.contentView = hostingView

            floatingWindow = window
        }

        // Center window on screen
        if let window = floatingWindow, let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowFrame = window.frame
            let x = (screenFrame.width - windowFrame.width) / 2
            let y = (screenFrame.height - windowFrame.height) / 2 + 100 // Slightly above center
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show window WITHOUT stealing focus
        floatingWindow?.orderFront(nil)
        // DO NOT call makeKeyAndOrderFront or NSApp.activate - that steals focus!
    }

@MainActor
    func hideWindow() {
        floatingWindow?.orderOut(nil)
    }

    func setupKeyboardShortcut() {
        // Handler for right option key - must dispatch to main actor
        let handler: (NSEvent) -> Void = { [weak self] event in
            // Right Option key (keyCode 61)
            guard event.keyCode == 61 else { return }

            let isPressed = event.modifierFlags.contains(.option)

            // Dispatch all main-actor-isolated property access to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }

                print("🔑 Right Option key event - isPressed: \(isPressed), wasPressed: \(self.rightOptionKeyWasPressed)")

                // Key pressed down
                if isPressed && !self.rightOptionKeyWasPressed {
                    print("⬇️ Key pressed DOWN")
                    self.handleKeyPressDown()
                }
                // Key released
                else if !isPressed && self.rightOptionKeyWasPressed {
                    print("⬆️ Key released UP")
                    self.handleKeyRelease()
                }

                // Update state
                self.rightOptionKeyWasPressed = isPressed
            }
        }

        // Global monitor (for when app is not active)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
        }

        // Local monitor (for when app is active)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
    }

    func handleKeyPressDown() {
        print("🎯 handleKeyPressDown - START")
        print("   isRecording: \(audioRecorder.isRecording)")

        // Record the press time
        keyPressStartTime = Date()
        isPushToTalkMode = false
        isWaitingForRelease = true
        print("   State set: keyPressStartTime, isPushToTalkMode=false, isWaitingForRelease=true")

        // If already recording (from a previous click-to-record), stop it
        if audioRecorder.isRecording {
            print("⏹️ Already recording (click mode) - stopping")
            audioRecorder.stopRecording()
            isWaitingForRelease = false
            print("   Stopped recording, returning")
            return
        }

        // Show window if not visible
        print("   Checking window visibility...")
        if floatingWindow == nil || floatingWindow?.isVisible == false {
            print("   Window not visible, calling showWindow()")
            showWindow()
            print("   showWindow() completed")
        } else {
            print("   Window already visible")
        }

        // Start recording immediately
        print("▶️ Starting recording - calling startRecordingWithCallback()")
        startRecordingWithCallback()
        print("   startRecordingWithCallback() completed")

        // Schedule a check to see if this becomes push-to-talk mode
        DispatchQueue.main.asyncAfter(deadline: .now() + pushToTalkThreshold) { [weak self] in
            guard let self = self else { return }

            // If key is still held down after threshold, it's push-to-talk mode
            if self.rightOptionKeyWasPressed && self.isWaitingForRelease {
                print("🎤 Switched to PUSH-TO-TALK mode (held > \(self.pushToTalkThreshold)s)")
                self.isPushToTalkMode = true
            }
        }
    }

    func handleKeyRelease() {
        print("🎯 handleKeyRelease - isPushToTalk: \(isPushToTalkMode), isWaitingForRelease: \(isWaitingForRelease)")

        guard let startTime = keyPressStartTime else { return }
        let pressDuration = Date().timeIntervalSince(startTime)
        print("⏱️ Key press duration: \(pressDuration)s")

        // If this was push-to-talk mode, stop recording on release
        if isPushToTalkMode && audioRecorder.isRecording {
            print("⏹️ Push-to-talk mode - stopping on release")
            audioRecorder.stopRecording()
        }
        // If released quickly (before threshold), it's click-to-record mode
        // Recording continues until next press
        else if pressDuration < pushToTalkThreshold {
            print("🔄 Click-to-record mode - recording continues")
            // Recording stays active, will be stopped on next key press
        }

        // Reset state
        keyPressStartTime = nil
        isPushToTalkMode = false
        isWaitingForRelease = false
    }

    func startRecordingWithCallback() {
        print("   startRecordingWithCallback - setting up callback")
        audioRecorder.onRecordingComplete = { [weak self] audioURL in
            print("   🎙️ Recording complete callback triggered")
            self?.transcriptionService.setAudioFileURL(audioURL)
        }
        print("   startRecordingWithCallback - calling audioRecorder.startRecording()")
        audioRecorder.startRecording()
        print("   startRecordingWithCallback - calling transcriptionService.startTranscription()")
        transcriptionService.startTranscription()
        print("   startRecordingWithCallback - DONE")
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Talkies Settings"
            window.center()

            let settingsView = SettingsView()
            window.contentView = NSHostingView(rootView: settingsView)

            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}