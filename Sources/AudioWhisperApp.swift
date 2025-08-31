import SwiftUI
import SwiftData
import AppKit
import HotKey
import ServiceManagement
import os.log

@main
struct AudioWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // This is a menu bar app, so we just need to define menu commands
        // All windows are created programmatically
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .onAppear {
                    // Hide the empty window immediately
                    NSApplication.shared.windows.first?.orderOut(nil)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(LocalizedStrings.Menu.settings) {
                    appDelegate.openSettings()
                }
                // Remove keyboard shortcut hint for menu bar app
            }
            CommandGroup(replacing: .windowArrangement) {
                Button(LocalizedStrings.Menu.closeWindow) {
                    NSApplication.shared.keyWindow?.orderOut(nil)
                }
                // No keyboard shortcut hints
            }
        }
    }
    
    /// Creates a fallback container if DataManager initialization fails
    private func createFallbackContainer() -> ModelContainer {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var keyboardEventHandler: KeyboardEventHandler?
    private var windowController = WindowController()
    private weak var recordingWindow: NSWindow?
    private var recordingWindowDelegate: RecordingWindowDelegate?
    private var audioRecorder: AudioRecorder?
    private var recordingAnimationTimer: DispatchSourceTimer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI initialization in test environment
        let isTestEnvironment = NSClassFromString("XCTestCase") != nil
        if isTestEnvironment {
            Logger.app.info("Test environment detected - skipping UI initialization")
            return
        }
        
        // Initialize DataManager first
        do {
            try DataManager.shared.initialize()
            Logger.app.info("DataManager initialized successfully")
        } catch {
            Logger.app.error("Failed to initialize DataManager: \(error.localizedDescription)")
            // App continues with in-memory fallback
        }
        
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
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.history, action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.settings, action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusItem?.menu = menu
        
        // Set up global hotkey and keyboard monitoring
        hotKeyManager = HotKeyManager { [weak self] in
            self?.handleHotkey()
        }
        keyboardEventHandler = KeyboardEventHandler()
        
        // Listen for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
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
            name: .openSettingsRequested,
            object: nil
        )
        
        // Listen for welcome completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onWelcomeCompleted),
            name: .welcomeCompleted,
            object: nil
        )
        
        // Listen for focus restoration requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restoreFocusToPreviousApp),
            name: .restoreFocusToPreviousApp,
            object: nil
        )
        
        // Listen for recording stopped notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRecordingStopped),
            name: .recordingStopped,
            object: nil
        )
    }
    
    private func handleHotkey() {
        let immediateRecording = UserDefaults.standard.bool(forKey: "immediateRecording")
        
        if immediateRecording {
            // Mode 2: Hotkey Start & Stop
            guard let recorder = audioRecorder else {
                Logger.app.error("AudioRecorder not available for immediate recording")
                // Fallback to showing window if recorder not available
                toggleRecordWindow()
                return
            }
            
            if recorder.isRecording {
                // Stop recording and process - show window for processing UI
                updateMenuBarIcon(isRecording: false)
                // Only show window if it's not already visible
                if recordingWindow == nil || !recordingWindow!.isVisible {
                    toggleRecordWindow()
                }
                
                // Tiny delay to ensure onAppear runs first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
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

                    // Play recording start sound if enabled
                    SoundManager().playRecordingStartSound()
                } else {
                    // Failed - show window with error
                    toggleRecordWindow()
                    // Notify ContentView to show error
                    NotificationCenter.default.post(
                        name: .recordingStartFailed,
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
        stopRecordingAnimation()
        
        // Use the same adaptive sizing as the normal icon
        let iconSize = AppSetupHelper.getAdaptiveMenuBarIconSize()
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        
        // Create red version: red circle outline with red microphone
        let redImage = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        redImage?.isTemplate = false
        let redOutlineImage = redImage?.tinted(with: .systemRed)
        
        // Create black version: use template image so it follows system appearance
        let blackImage = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: "Recording")?.withSymbolConfiguration(config)
        blackImage?.isTemplate = true  // Template images automatically adapt to menu bar appearance
        
        // Start with red state
        button.image = redOutlineImage
        
        var isRedState = true // Start as red since we just set red image
        
        // Create DispatchSourceTimer on background queue for efficiency
        let queue = DispatchQueue(label: "com.audiowhisper.animation", qos: .background)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        
        // Schedule timer to start immediately and repeat every 0.5 seconds
        timer.schedule(deadline: .now(), repeating: 0.5)
        
        timer.setEventHandler { [weak button] in
            guard let button = button else { return }
            
            // Toggle the state
            isRedState.toggle()
            
            // Update UI on main thread
            DispatchQueue.main.async {
                button.image = isRedState ? redOutlineImage : blackImage
            }
        }
        
        recordingAnimationTimer = timer
        timer.resume()
    }
    
    private func stopRecordingAnimation() {
        recordingAnimationTimer?.cancel()
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
        // Ensure audioRecorder is available
        guard let recorder = audioRecorder else {
            Logger.app.error("Cannot create recording window: AudioRecorder not initialized")
            return
        }
        
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
        let contentView = ContentView(audioRecorder: recorder)
            .frame(width: 280, height: 160)
            .fixedSize()
            .background(VisualEffectView())
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .modelContainer(DataManager.shared.sharedModelContainer ?? createFallbackModelContainer())
        
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        
        // Hide standard window buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set up delegate to handle window lifecycle
        recordingWindowDelegate = RecordingWindowDelegate { [weak self] in
            self?.onRecordingWindowClosed()
        }
        window.delegate = recordingWindowDelegate
        
        recordingWindow = window
    }
    
    /// Called when the recording window is closing
    private func onRecordingWindowClosed() {
        // Clean up references
        recordingWindow = nil
        recordingWindowDelegate = nil
        Logger.app.info("Recording window closed and references cleaned up")
    }
    
    /// Creates a fallback container if DataManager initialization fails
    private func createFallbackModelContainer() -> ModelContainer {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }
    
    @objc private func restoreFocusToPreviousApp() {
        windowController.restoreFocusToPreviousApp()
    }
    
    @objc private func onRecordingStopped() {
        // Stop the red flashing animation when recording stops (entering processing phase)
        updateMenuBarIcon(isRecording: false)
    }
    
    @objc func openSettings() {
        windowController.openSettings()
    }
    
    
    @objc func onWelcomeCompleted() {
        // Nothing needed - the recording window exists and will be shown by hotkey
    }
    
    
    @MainActor @objc func showHistory() {
        Logger.app.info("History menu item selected")
        HistoryWindowManager.shared.showHistoryWindow()
    }
    
    @objc func showHelp() {
        // Show the welcome dialog as help
        let shouldOpenSettings = WelcomeWindow.showWelcomeDialog()
        
        if shouldOpenSettings {
            openSettings()
        }
    }
    
    @objc private func screenConfigurationChanged() {
        // Reset the cached icon size when screen configuration changes
        AppSetupHelper.resetIconSizeCache()
        
        // Update the menu bar icon with the new size
        if let button = statusItem?.button {
            button.image = AppSetupHelper.createMenuBarIcon()
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
        recordingAnimationTimer?.cancel()
        recordingAnimationTimer = nil
        
        // Clean up window references
        recordingWindow = nil
        recordingWindowDelegate = nil
        
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
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Window delegate that handles the recording window lifecycle
private class RecordingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
