import SwiftUI
import AppKit
import HotKey
import ServiceManagement
import os.log

@main
struct AudioWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Settings window - normal chrome
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(LocalizedStrings.Menu.settings) {
                    appDelegate.openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .windowArrangement) {
                Button(LocalizedStrings.Menu.closeWindow) {
                    NSApplication.shared.keyWindow?.orderOut(nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }
    
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var keyboardEventHandler: KeyboardEventHandler?
    private var windowController = WindowController()
    private var recordingWindow: NSWindow?
    private var audioRecorder: AudioRecorder?
    private var recordingAnimationTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup app configuration
        AppSetupHelper.setupApp()
        
        // Initialize audio recorder
        audioRecorder = AudioRecorder()
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = AppSetupHelper.createMenuBarIcon()
            button.action = #selector(toggleRecordWindow)
            button.target = self
        }
        
        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.record, action: #selector(toggleRecordWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.settings, action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Set up global hotkey and keyboard monitoring
        hotKeyManager = HotKeyManager { [weak self] in
            self?.handleHotkey()
        }
        keyboardEventHandler = KeyboardEventHandler()
        
        // Setup additional notification observers
        setupNotificationObservers()

        // Check for first run and show settings if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if AppSetupHelper.checkFirstRun() {
                self.showWelcomeAndSettings()
            }
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for settings requests from error dialogs
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettingsRequested"),
            object: nil
        )
        
        // Listen for welcome completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWelcomeCompleted),
            name: NSNotification.Name("WelcomeCompleted"),
            object: nil
        )
        
        // Listen for focus restoration requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restoreFocusToPreviousApp),
            name: NSNotification.Name("RestoreFocusToPreviousApp"),
            object: nil
        )
    }
    
    private func handleHotkey() {
        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")
        
        if immediateRecording {
            // Mode 2: Hotkey Start & Stop
            guard let recorder = audioRecorder else {
                // Fallback to showing window if recorder not available
                toggleRecordWindow()
                return
            }
            
            if recorder.isRecording {
                // Stop recording and process - show window for processing UI
                updateMenuBarIcon(isRecording: false)
                toggleRecordWindow()
                
                // Tiny delay to ensure onAppear runs first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: NSNotification.Name("SpaceKeyPressed"), object: nil)
                }
            } else {
                // Check permission first
                if !recorder.hasPermission {
                    // Show window for permission UI
                    toggleRecordWindow()
                    return
                }
                
                // Try to start recording
                if recorder.startRecording() {
                    // Success - recording started in background
                    updateMenuBarIcon(isRecording: true)
                } else {
                    // Failed - show window with error
                    toggleRecordWindow()
                    // Notify ContentView to show error
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RecordingStartFailed"),
                        object: nil
                    )
                }
            }
        } else {
            // Mode 1: Manual Start & Stop (original behavior)
            toggleRecordWindow()
        }
    }
    
    private func updateMenuBarIcon(isRecording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            
            if isRecording {
                self.startRecordingAnimation()
            } else {
                self.stopRecordingAnimation()
                // Use normal microphone icon
                button.image = AppSetupHelper.createMenuBarIcon()
            }
        }
    }
    
    private func startRecordingAnimation() {
        guard let button = statusItem?.button else { return }
        
        // Stop any existing animation
        recordingAnimationTimer?.invalidate()
        
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let normalImage = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        let filledImage = NSImage(systemSymbolName: "microphone.circle.fill", accessibilityDescription: "Recording in progress")?.withSymbolConfiguration(config)
        
        normalImage?.isTemplate = true
        filledImage?.isTemplate = true
        
        // Start with filled state immediately
        button.image = filledImage
        
        var isFilledState = true // Start as filled since we just set it
        
        // Schedule animation with shorter interval and immediate first change
        recordingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            button.image = isFilledState ? normalImage : filledImage
            isFilledState.toggle()
        }
    }
    
    private func stopRecordingAnimation() {
        recordingAnimationTimer?.invalidate()
        recordingAnimationTimer = nil
    }
    
    @objc func toggleRecordWindow() {
        // Create recording window on-demand if it doesn't exist
        if recordingWindow == nil {
            createRecordingWindow()
        }
        windowController.toggleRecordWindow(recordingWindow)
    }
    
    private func createRecordingWindow() {
        // Create the recording window programmatically
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        window.title = "AudioWhisper Recording"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isOpaque = false
        
        // Create ContentView and set it as content
        let contentView = ContentView(audioRecorder: audioRecorder!)
            .frame(width: 280, height: 160)
            .fixedSize()
            .background(VisualEffectView())
        
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        
        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        recordingWindow = window
    }
    
    @objc private func restoreFocusToPreviousApp() {
        windowController.restoreFocusToPreviousApp()
    }
    
    @objc func openSettings() {
        windowController.openSettings()
    }
    
    
    @objc func onWelcomeCompleted() {
        // Nothing needed - the recording window exists and will be shown by hotkey
    }
    
    
    @objc func showHelp() {
        // Show the welcome dialog as help
        let shouldOpenSettings = WelcomeWindow.showWelcomeDialog()
        
        if shouldOpenSettings {
            openSettings()
        }
    }
    
    func hasAPIKey(service: String, account: String) -> Bool {
        return KeychainService.shared.getQuietly(service: service, account: account) != nil
    }
    
    func showWelcomeAndSettings() {
        let shouldOpenSettings = WelcomeWindow.showWelcomeDialog()
        
        if shouldOpenSettings {
            openSettings()
        }
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in menu bar
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
        recordingAnimationTimer?.invalidate()
        recordingAnimationTimer = nil
        
        // Cleanup is handled by the deinitializers of the helper classes
        AppSetupHelper.cleanupOldTemporaryFiles()
    }
    
}

// Custom window class that can become key and handle keyboard input
class ChromelessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

// Visual effect view for background blur
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        effectView.material = .hudWindow
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
