import SwiftUI
import AVFoundation
import AppKit
import TalkiesCore
import TalkiesInference
import TalkiesAudio
import TalkiesAccessibility
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
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
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
    /// Each recording's mode and insertion destination, bound at key press.
    private var captures = CaptureLedger<TextInsertionDestination>()
    private var statusIconSubscriptions = Set<AnyCancellable>()

    // Agent mode: a separate hotkey whose utterances go to agents, never into the focused field.
    let agentController = AgentModeController()
    /// The agent capture whose key is currently held.
    private var activeAgentCapture: (ticket: CaptureTicket, pressedAt: Date)?
    var agentKeyWasPressed = false
    private var escapeMonitors: [Any] = []
    private let agentTargetMenu = NSMenu(title: "Agent Target")

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
        transcriptionService.onTranscriptionComplete = { [weak self] text, ticket in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Route by the capture that produced this text, never by the key pressed last.
                if let ticket {
                    guard let mode = self.captures.mode(of: ticket) else { return } // discarded
                    if mode == .agent {
                        // Agent text is parsed as recognized: no S1-mini, Ollama, or LM Studio rewriting.
                        self.finishAgentCapture(text, ticket: ticket)
                        return
                    }
                }
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

                let destination: TextInsertionDestination?
                switch ticket.map({ self.captures.finish($0, text: finalText) }) ?? .insert(finalText, destination: nil) {
                case .insert(let routed, let routedDestination):
                    finalText = routed
                    destination = routedDestination
                case .agent, .dropped:
                    return
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
                    let target = destination?.applicationName ?? "the previous app"
                    self.transcriptionService.statusMessage = "Returning to \(target)…"
                    let result = await TextInserter.shared.insertTextAtCursor(finalText, into: destination)
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
        setupAgentMode()
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
        let agentTargetItem = NSMenuItem(title: "Agent Target", action: nil, keyEquivalent: "")
        agentTargetMenu.delegate = self
        agentTargetItem.submenu = agentTargetMenu
        menu.addItem(agentTargetItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Talkies", action: #selector(quitApp), keyEquivalent: "q"))

        // Set target for menu items
        for item in menu.items where item.submenu == nil {
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
            let contentView = DictationView(agentController: agentController, isCollapsed: collapsedBinding, onToggleRecording: { [weak self] in
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
        agentController.isDictationInProgress = false
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
        switch agentController.phase {
        case .pending, .working, .choosing: return false
        case .idle, .listening, .notice: break
        }
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
            let deviceFlags = event.modifierFlags.rawValue

            // Dispatch all main-actor-isolated property access to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                let selectedKeyCode = self.settingsService.settings.activationKey?.rawValue ?? ActivationKey.rightOption.rawValue
                if let agentHotkey = self.agentHotkey {
                    if Int(keyCode) == agentHotkey.keyCode {
                        let agentKeyPressed = deviceFlags & agentHotkey.deviceFlagMask != 0
                        if agentKeyPressed && !self.agentKeyWasPressed {
                            self.agentKeyWasPressed = true
                            self.agentKeyDown(agentHotkey, rawFlags: deviceFlags)
                        } else if !agentKeyPressed && self.agentKeyWasPressed {
                            self.agentKeyWasPressed = false
                            self.agentKeyUp()
                        }
                        return
                    }
                    if self.agentKeyWasPressed, !agentHotkey.isSolePress(rawFlags: deviceFlags) {
                        // Another modifier joined the hold: it's a shortcut, not an agent capture.
                        self.abortAgentCapture()
                    }
                }
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

    @discardableResult
    func startRecordingWithCallback(mode: CaptureMode = .dictation) -> CaptureTicket? {
        print("   startRecordingWithCallback - setting up callback")

        guard audioRecorder.hasPermission else {
            transcriptionService.pipelineStage = .requestingMicrophonePermission
            transcriptionService.statusMessage = "Allow microphone access, then try again."
            audioRecorder.requestMicrophonePermission()
            return nil
        }

        // Set pipeline stage to recording
        transcriptionService.currentText = ""
        transcriptionService.pipelineStage = .recording
        let ticket: CaptureTicket
        let vocabulary: [String]
        switch mode {
        case .dictation:
            ticket = captures.begin(.dictation, destination: TextInserter.shared.captureDestination())
            vocabulary = []
            transcriptionService.statusMessage = "Listening… audio stays on this Mac."
            agentController.dictationStarted()
        case .agent:
            // Agent mode never inserts text, so the focused field is not captured.
            ticket = captures.begin(.agent)
            vocabulary = agentController.spokenNames
            transcriptionService.statusMessage = "Listening for an agent command… audio stays on this Mac."
            agentController.beginListening()
        }

        audioRecorder.onRecordingComplete = { [weak self] audioURL in
            print("   🎙️ Recording complete callback triggered")
            guard let self else { return }
            guard self.captures.mode(of: ticket) != nil else {
                // A discarded capture (short tap or shortcut) is never transcribed.
                try? FileManager.default.removeItem(at: audioURL)
                return
            }
            self.transcriptionService.pipelineStage = .transcribing
            self.transcriptionService.setAudioFileURL(audioURL, ticket: ticket, extraVocabulary: vocabulary)
        }
        print("   startRecordingWithCallback - calling audioRecorder.startRecording()")
        audioRecorder.startRecording()
        guard audioRecorder.isRecording else {
            let message = audioRecorder.errorMessage ?? "Could not start microphone recording."
            transcriptionService.pipelineStage = .error(message)
            transcriptionService.statusMessage = message
            if captures.finishWithoutText(ticket) == .agent { agentController.captureEndedWithoutSpeech() }
            return nil
        }
        print("   startRecordingWithCallback - calling transcriptionService.startTranscription()")
        transcriptionService.startTranscription()
        print("   startRecordingWithCallback - DONE")
        return ticket
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

    // MARK: - Agent mode

    /// The agent hotkey when agent mode is on and it is not the dictation key.
    private var agentHotkey: AgentHotkey? {
        guard let agentMode = settingsService.settings.agentMode, agentMode.isEnabled,
              let hotkey = agentMode.hotkey else { return nil }
        let dictationKey = settingsService.settings.activationKey ?? .rightOption
        return hotkey.conflicts(with: dictationKey) ? nil : hotkey
    }

    /// Agent mode is hold-to-talk: the key must be pressed alone, and held long enough.
    private func agentKeyDown(_ hotkey: AgentHotkey, rawFlags: UInt) {
        guard hotkey.isSolePress(rawFlags: rawFlags) else { return } // part of a shortcut
        guard !audioRecorder.isRecording else { return } // never take over a capture in progress
        if floatingWindow == nil || floatingWindow?.isVisible == false {
            showWindow()
        } else {
            expandWindow()
        }
        guard let ticket = startRecordingWithCallback(mode: .agent) else { return }
        activeAgentCapture = (ticket, Date())
    }

    private func agentKeyUp() {
        guard let capture = activeAgentCapture else { return }
        activeAgentCapture = nil
        guard Date().timeIntervalSince(capture.pressedAt) >= AgentHotkey.minimumHoldSeconds else {
            // A tap never leaves the microphone open.
            discardAgentCapture(capture.ticket)
            return
        }
        if audioRecorder.isRecording { audioRecorder.stopRecording() }
    }

    /// Another key was pressed during the hold, so this was a shortcut such as ⌘C.
    private func abortAgentCapture() {
        guard let capture = activeAgentCapture else { return }
        activeAgentCapture = nil
        discardAgentCapture(capture.ticket)
    }

    private func discardAgentCapture(_ ticket: CaptureTicket) {
        captures.cancel(ticket)
        if audioRecorder.isRecording { audioRecorder.stopRecording() }
        transcriptionService.pipelineStage = .idle
        transcriptionService.statusMessage = "Ready to dictate"
        agentController.captureEndedWithoutSpeech()
        if !agentController.isActive { collapseWindow() }
    }

    private func setupAgentMode() {
        // Esc cancels a pending tier-1 send. Global key monitoring needs Accessibility approval;
        // the HUD's Cancel button works without it.
        // Any key pressed while the agent key is held marks the press as a shortcut.
        let cancelOnEscape: (NSEvent) -> Void = { [weak self] event in
            let isEscape = event.keyCode == 53
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.activeAgentCapture != nil {
                    self.abortAgentCapture()
                } else if isEscape {
                    self.agentController.cancelPending()
                }
            }
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: cancelOnEscape) {
            escapeMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            cancelOnEscape(event)
            return event
        }) {
            escapeMonitors.append(monitor)
        }

        // A capture with no usable speech, or a failed one, closes its own ticket.
        transcriptionService.onTranscriptionEndedWithoutText = { [weak self] ticket in
            Task { @MainActor [weak self] in
                guard let self, let ticket, self.captures.finishWithoutText(ticket) == .agent else { return }
                self.agentController.captureEndedWithoutSpeech()
            }
        }

        settingsService.$settings
            .map { _ in () }
            .sink { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.agentController.agentKeyName = self.agentHotkey?.displayName
                }
            }
            .store(in: &statusIconSubscriptions)

        if settingsService.settings.agentMode?.isEnabled == true {
            Task { await agentController.refreshAgents() }
        }
    }

    /// Agent-mode text is parsed for an agent and is never inserted into the focused field.
    /// It still lands in the transcript list like any dictation.
    private func finishAgentCapture(_ text: String, ticket: CaptureTicket) {
        let recognized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .agent(let trimmed) = captures.finish(ticket, text: recognized) else { return }
        transcriptionService.currentText = trimmed
        guard !trimmed.isEmpty else {
            transcriptionService.pipelineStage = .noSpeech
            transcriptionService.statusMessage = "No usable words were recognized. Try again."
            agentController.captureEndedWithoutSpeech()
            return
        }
        transcriptionService.pipelineStage = .complete
        transcriptionService.statusMessage = "Agent mode: \(trimmed)"
        Task { await agentController.handle(trimmed) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === agentTargetMenu else { return }
        rebuildAgentTargetMenu()
        guard settingsService.settings.agentMode?.isEnabled == true else { return }
        Task { [weak self] in
            guard let self, await self.agentController.refreshAgents() else { return }
            self.rebuildAgentTargetMenu()
        }
    }

    private func rebuildAgentTargetMenu() {
        agentTargetMenu.removeAllItems()
        guard settingsService.settings.agentMode?.isEnabled == true else {
            let item = NSMenuItem(title: "Turn On Agent Mode in Settings…", action: #selector(showSettings), keyEquivalent: "")
            item.target = self
            agentTargetMenu.addItem(item)
            return
        }
        if agentHotkey == nil {
            let item = NSMenuItem(title: "Choose an Agent Key in Settings…", action: #selector(showSettings), keyEquivalent: "")
            item.target = self
            agentTargetMenu.addItem(item)
            agentTargetMenu.addItem(.separator())
        }
        let agents = agentController.agents
        if agents.isEmpty {
            let item = NSMenuItem(title: agentController.lastListError ?? "No cmux agents found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            agentTargetMenu.addItem(item)
        }
        var lastWorkspace: String?
        for (index, agent) in agents.enumerated() {
            if index == 0 || agent.workspace != lastWorkspace {
                if index > 0 { agentTargetMenu.addItem(.separator()) }
                let header = NSMenuItem(title: agent.workspace ?? "cmux", action: nil, keyEquivalent: "")
                header.isEnabled = false
                agentTargetMenu.addItem(header)
                lastWorkspace = agent.workspace
            }
            let item = NSMenuItem(title: "\(index + 1). \(agent.name) · \(agent.status.spokenPhrase)", action: #selector(selectAgentTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = agent.id
            item.state = agent.id == agentController.selectedTargetID ? .on : .off
            item.indentationLevel = 1
            agentTargetMenu.addItem(item)
        }
        agentTargetMenu.addItem(.separator())
        let refresh = NSMenuItem(title: "Refresh Agents", action: #selector(refreshAgentTargets), keyEquivalent: "")
        refresh.target = self
        agentTargetMenu.addItem(refresh)
    }

    @objc private func selectAgentTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let agent = agentController.agents.first(where: { $0.id == id }) else { return }
        agentController.select(agent)
    }

    @objc private func refreshAgentTargets() {
        Task { await agentController.refreshAgents() }
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
        for monitor in escapeMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }
}
