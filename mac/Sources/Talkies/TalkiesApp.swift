import SwiftUI
import AVFoundation
import AppKit
import TalkiesCore
import TalkiesInference
import TalkiesAudio
import Combine

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
    private let s1MiniCleaner = S1MiniCleaner()
    private let fallbackSpeechSynthesizer = AVSpeechSynthesizer()
    var statusItem: NSStatusItem?
    var floatingWindow: NSWindow?
    private var settingsWindowController: NSWindowController?
    var audioRecorder = AudioRecorder()
    var transcriptionService = TranscriptionService()
    var eventMonitor: Any?
    var localEventMonitor: Any?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var isDismissingFloatingWindow = false
    private var isFloatingWindowCollapsed = true
    var activationKeyWasPressed = false
    private var insertionDestination: TextInsertionDestination?
    private var statusIconSubscriptions = Set<AnyCancellable>()

    // Settings service
    var settingsService = SettingsService.shared

    // Intelligent mode detection
    var keyPressStartTime: Date?
    var isPushToTalkMode = false
    var isWaitingForRelease = false

    var pushToTalkThreshold: TimeInterval {
        settingsService.settings.pushToTalkThreshold
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Crash Logger
        CrashLogger.shared.setup()

        // Migrate from UserDefaults if needed (one-time)
        settingsService.migrateFromUserDefaults()
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusBarIcon()

            // Handle left and right clicks differently
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            button.action = #selector(handleStatusBarClick(_:))
        }

        // Create menu for right-click (but don't set it yet)
        setupStatusBarMenu()
        observeStatusIconState()

        // Setup transcription completion callback
        transcriptionService.onTranscriptionComplete = { [weak self] text in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                var finalText = text
                var cleanupFailed = false
                let s1MiniEnabled = self.settingsService.settings.s1Mini?.isEnabled ?? false

                if let cleanupSettings = self.settingsService.settings.s1Mini, s1MiniEnabled {
                    self.transcriptionService.pipelineStage = .cleaningS1Mini
                    self.transcriptionService.statusMessage = "Polishing your transcript locally…"
                    do {
                        let options = TranscriptCleanupOptions(style: cleanupSettings.style, structure: cleanupSettings.structure, context: cleanupSettings.context)
                        let cleanedText = try await self.s1MiniCleaner.clean(text, options: options)
                        if !cleanedText.isEmpty {
                            finalText = cleanedText
                        }
                    } catch {
                        cleanupFailed = true
                        print("⚠️ S1-mini cleanup failed; using raw transcript: \(error.localizedDescription)")
                    }
                }

                let ollamaEnabled = PluginManager.shared.ollamaPlugin?.isEnabled ?? false
                let lmStudioEnabled = PluginManager.shared.lmStudioPlugin?.isEnabled ?? false
                if !s1MiniEnabled && ollamaEnabled && !lmStudioEnabled, let plugin = PluginManager.shared.ollamaPlugin {
                    self.transcriptionService.pipelineStage = .enhancingOllama
                    self.transcriptionService.statusMessage = "Enhancing locally with Ollama…"
                    do { finalText = try await plugin.enhanceText(text) }
                    catch { cleanupFailed = true; print("⚠️ Ollama enhancement failed: \(error.localizedDescription)") }
                } else if !s1MiniEnabled && lmStudioEnabled && !ollamaEnabled, let plugin = PluginManager.shared.lmStudioPlugin {
                    self.transcriptionService.pipelineStage = .enhancingLMStudio
                    self.transcriptionService.statusMessage = "Enhancing locally with LM Studio…"
                    do { finalText = try await plugin.enhanceText(text) }
                    catch { cleanupFailed = true; print("⚠️ LM Studio enhancement failed: \(error.localizedDescription)") }
                }

                self.transcriptionService.currentText = finalText
                guard !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.transcriptionService.pipelineStage = .noSpeech
                    self.transcriptionService.statusMessage = "No usable words were recognized. Try again."
                    return
                }
                if cleanupFailed {
                    self.transcriptionService.pipelineStage = .cleanupFallback
                    self.transcriptionService.statusMessage = "Cleanup failed; keeping the recognized words."
                }

                let voiceMode = self.settingsService.settings.voiceAssistantMode
                let shouldInsert = !voiceMode || self.settingsService.settings.insertTextInAssistantMode
                if shouldInsert {
                    self.transcriptionService.pipelineStage = .insertingText
                    let target = self.insertionDestination?.applicationName ?? "the previous app"
                    self.transcriptionService.statusMessage = "Returning to \(target)…"
                    let result = await TextInserter.shared.insertTextAtCursor(finalText, into: self.insertionDestination)
                    switch result {
                    case .inserted(let applicationName):
                        self.transcriptionService.pipelineStage = cleanupFailed ? .cleanupFallback : .complete
                        self.transcriptionService.statusMessage = "Text inserted into \(applicationName)."
                    case .manualPasteRequired(let reason):
                        self.transcriptionService.pipelineStage = .clipboardFallback(reason)
                        self.transcriptionService.statusMessage = reason
                        return
                    case .failed(let reason):
                        self.transcriptionService.pipelineStage = .error(reason)
                        self.transcriptionService.statusMessage = reason
                        return
                    }
                }

                if voiceMode {
                    let utterance = AVSpeechUtterance(string: finalText)
                    self.fallbackSpeechSynthesizer.speak(utterance)
                    self.transcriptionService.statusMessage = shouldInsert ? "Inserted and speaking your response." : "Speaking your response."
                    if !cleanupFailed { self.transcriptionService.pipelineStage = .complete }
                }

                // Leave a readable success state briefly. Errors and manual-paste
                // states stay visible until the user dismisses the panel.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    guard let self, self.transcriptionService.pipelineStage == .complete || self.transcriptionService.pipelineStage == .cleanupFallback else { return }
                    self.collapseWindow()
                    self.transcriptionService.pipelineStage = .idle
                }
            }
        }

        // Setup global keyboard shortcut (Cmd+Shift+Space)
        setupKeyboardShortcut()
        setupFloatingWindowDismissal()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showWindow(expanded: false)
        }

        // Hide dock icon and make menu bar only
        NSApp.setActivationPolicy(.accessory)
    }

    private func observeStatusIconState() {
        audioRecorder.$isRecording
            .combineLatest(transcriptionService.$pipelineStage)
            .sink { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.updateStatusBarIcon() }
            }
            .store(in: &statusIconSubscriptions)
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        let state = MenuBarStatusIcon.state(
            isRecording: audioRecorder.isRecording,
            stage: transcriptionService.pipelineStage
        )
        button.image = MenuBarStatusIcon.image(for: state)
        button.toolTip = state.accessibilityLabel
        button.setAccessibilityLabel(state.accessibilityLabel)
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
        expandWindow()
    }

    @objc func toggleWindow() {
        if let window = floatingWindow, window.isVisible {
            if isFloatingWindowCollapsed {
                expandWindow()
            } else {
                collapseWindow()
            }
        } else {
            showWindow()
        }
    }

@MainActor
    func showWindow(expanded: Bool = true) {
        isDismissingFloatingWindow = false
        isFloatingWindowCollapsed = !expanded
        if floatingWindow == nil {
            // Create floating window
            let window = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: expanded ? (settingsService.settings.useMinimalDictationWindow == true ? 360 : 560) : 124,
                    height: expanded ? (settingsService.settings.useMinimalDictationWindow == true ? 126 : 184) : 38
                ),
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
            let collapsedBinding = Binding(
                get: { [weak self] in self?.isFloatingWindowCollapsed ?? true },
                set: { [weak self] collapsed in self?.isFloatingWindowCollapsed = collapsed }
            )
            let contentView = DictationView(isCollapsed: collapsedBinding, onToggleRecording: { [weak self] in
                self?.toggleRecordingFromFloatingWindow()
            }, onResize: { [weak self] size in
                self?.resizeFloatingWindow(to: size)
            })
                .environmentObject(audioRecorder)
                .environmentObject(transcriptionService)

            let hostingView = NSHostingView(rootView: contentView)
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 28
            hostingView.layer?.masksToBounds = true

            window.contentView = hostingView

            floatingWindow = window
        }

        positionFloatingWindowAtAnchor()

        // Show window WITHOUT stealing focus
        floatingWindow?.alphaValue = 1
        floatingWindow?.orderFront(nil)
        // DO NOT call makeKeyAndOrderFront or NSApp.activate - that steals focus!
    }

    private func resizeFloatingWindow(to size: CGSize) {
        guard let window = floatingWindow else { return }
        window.setFrame(NSRect(origin: window.frame.origin, size: size), display: true, animate: true)
        positionFloatingWindowAtAnchor()
    }

    private func positionFloatingWindowAtAnchor() {
        guard let window = floatingWindow, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.midX - window.frame.width / 2, y: visible.maxY - window.frame.height - 34)
        window.setFrameOrigin(origin)
    }

    private func expandWindow() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isFloatingWindowCollapsed = false
        }
        if floatingWindow == nil || floatingWindow?.isVisible == false {
            showWindow(expanded: true)
        } else {
            resizeFloatingWindow(to: CGSize(
                width: settingsService.settings.useMinimalDictationWindow == true ? 360 : 560,
                height: settingsService.settings.useMinimalDictationWindow == true ? 126 : 184
            ))
        }
    }

    private func collapseWindow() {
        guard canCollapseFloatingWindow, !isFloatingWindowCollapsed,
              let window = floatingWindow, window.isVisible else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isFloatingWindowCollapsed = true
        }
        resizeFloatingWindow(to: CGSize(width: 124, height: 38))
    }

    func toggleRecordingFromFloatingWindow() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            return
        }

        guard audioRecorder.hasPermission else {
            transcriptionService.pipelineStage = .requestingMicrophonePermission
            transcriptionService.statusMessage = "Waiting for microphone permission…"
            audioRecorder.requestMicrophonePermission()
            return
        }

        startRecordingWithCallback()
    }

@MainActor
    func hideWindow() {
        guard let window = floatingWindow, window.isVisible, !isDismissingFloatingWindow else { return }
        isDismissingFloatingWindow = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor in
                window?.orderOut(nil)
                window?.alphaValue = 1
                self?.isDismissingFloatingWindow = false
            }
        }
    }

    private func setupFloatingWindowDismissal() {
        let dismissIfSafe: (NSEvent) -> Void = { [weak self] event in
            guard let self,
                  let window = self.floatingWindow,
                  window.isVisible,
                  self.canCollapseFloatingWindow else { return }

            let click = NSEvent.mouseLocation
            guard !window.frame.contains(click) else { return }
            self.collapseWindow()
        }

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: dismissIfSafe)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            dismissIfSafe(event)
            return event
        }
    }

    private var canCollapseFloatingWindow: Bool {
        guard !audioRecorder.isRecording else { return false }
        switch transcriptionService.pipelineStage {
        case .idle, .complete, .cleanupFallback, .clipboardFallback, .noSpeech, .error:
            return true
        case .loadingModel, .requestingMicrophonePermission, .recording, .transcribing,
             .enhancingOllama, .enhancingLMStudio, .cleaningS1Mini, .insertingText:
            return false
        }
    }

    func setupKeyboardShortcut() {
        // Handler for the selected Option key - must dispatch to main actor.
        let handler: (NSEvent) -> Void = { [weak self] event in
            let keyCode = event.keyCode
            let isPressed = event.modifierFlags.contains(.option)

            // Dispatch all main-actor-isolated property access to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                let selectedKeyCode = self.settingsService.settings.activationKey?.rawValue ?? ActivationKey.rightOption.rawValue
                guard Int(keyCode) == selectedKeyCode else { return }

                print("🔑 Activation key event - isPressed: \(isPressed), wasPressed: \(self.activationKeyWasPressed)")

                // Key pressed down
                if isPressed && !self.activationKeyWasPressed {
                    print("⬇️ Key pressed DOWN")
                    self.handleKeyPressDown()
                }
                // Key released
                else if !isPressed && self.activationKeyWasPressed {
                    print("⬆️ Key released UP")
                    self.handleKeyRelease()
                }

                // Update state
                self.activationKeyWasPressed = isPressed
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
            expandWindow()
            print("   Expanded the anchored Talkies panel")
        }

        // Start recording immediately
        print("▶️ Starting recording - calling startRecordingWithCallback()")
        startRecordingWithCallback()
        print("   startRecordingWithCallback() completed")

        // Schedule a check to see if this becomes push-to-talk mode
        DispatchQueue.main.asyncAfter(deadline: .now() + pushToTalkThreshold) { [weak self] in
            guard let self = self else { return }

            // If key is still held down after threshold, it's push-to-talk mode
            if self.activationKeyWasPressed && self.isWaitingForRelease {
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

        guard audioRecorder.hasPermission else {
            transcriptionService.pipelineStage = .requestingMicrophonePermission
            transcriptionService.statusMessage = "Allow microphone access, then try again."
            audioRecorder.requestMicrophonePermission()
            return
        }

        guard transcriptionService.canTranscribe else {
            transcriptionService.pipelineStage = .loadingModel
            transcriptionService.statusMessage = "Speech model is still loading. Try again shortly."
            return
        }

        // Set pipeline stage to recording
        insertionDestination = TextInserter.shared.captureDestination()
        transcriptionService.currentText = ""
        transcriptionService.pipelineStage = .recording
        transcriptionService.statusMessage = "Listening… audio stays on this Mac."

        audioRecorder.onRecordingComplete = { [weak self] audioURL in
            print("   🎙️ Recording complete callback triggered")
            self?.transcriptionService.pipelineStage = .transcribing
            self?.transcriptionService.setAudioFileURL(audioURL)
        }
        print("   startRecordingWithCallback - calling audioRecorder.startRecording()")
        audioRecorder.startRecording()
        guard audioRecorder.isRecording else {
            let message = audioRecorder.errorMessage ?? "Could not start microphone recording."
            transcriptionService.pipelineStage = .error(message)
            transcriptionService.statusMessage = message
            return
        }
        print("   startRecordingWithCallback - calling transcriptionService.startTranscription()")
        transcriptionService.startTranscription()
        print("   startRecordingWithCallback - DONE")
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            // Keep the window alive when the user closes it. AppKit's default
            // release-on-close behavior can leave a retained Swift reference
            // pointing at a deallocated window, which crashes on the next open.
            window.isReleasedWhenClosed = false
            window.title = "Talkies Settings"
            window.center()

            let settingsView = SettingsView()
            window.contentView = NSHostingView(rootView: settingsView)

            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
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
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
