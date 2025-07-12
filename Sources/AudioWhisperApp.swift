import SwiftUI
import AppKit
import HotKey
import ServiceManagement
import os.log

@main
struct AudioWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowManager = WindowManager()
    
    var body: some Scene {
        // Recording window - always the same, chromeless
        WindowGroup(id: "recording") {
            ContentView()
                .frame(width: 280, height: 160)
                .fixedSize()
                .background(VisualEffectView())
                .onAppear {
                    windowManager.setupRecordingWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
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
    var hotKey: HotKey?
    var globalKeyMonitor: Any?
    var windowManager: WindowManager?
    var previousApp: NSRunningApplication?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove the app from dock
        NSApp.setActivationPolicy(.accessory)
        
        // Set up login item if enabled
        setupLoginItem()
        
        // Clean up old temporary audio files
        cleanupOldTemporaryFiles()
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createMenuBarIcon()
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
        
        // Set up global hotkey (Cmd+Shift+Space by default)
        setupHotKey()
        
        // Set up global keyboard monitoring 
        setupGlobalKeyMonitoring()
        
        // Hide recording window initially (it will show when hotkey is pressed)
        DispatchQueue.main.async {
            let recordWindow = NSApp.windows.first { window in
                window.title == "AudioWhisper Recording"
            }
            recordWindow?.orderOut(nil)
        }

        // Check for first run and show settings if needed
        checkFirstRun()
    }
    
    func setupLoginItem() {
        let startAtLogin = UserDefaults.standard.object(forKey: "startAtLogin") as? Bool ?? true // Default to true
        
        if startAtLogin {
            try? SMAppService.mainApp.register()
        }
    }
    
    
    func setupGlobalKeyMonitoring() {
        // Use global monitor that works regardless of focus
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Check if recording window is visible
            if let window = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), window.isVisible {
                _ = self.handleKeyEvent(event, for: window)
            }
        }
        
        // Also add local monitor with proper filtering
        globalKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check if recording window is visible
            if let window = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), window.isVisible {
                return self.handleKeyEvent(event, for: window)
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent, for window: NSWindow) -> NSEvent? {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags
        
        // Handle space key
        if key == " " && !modifiers.contains(.command) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("SpaceKeyPressed"), object: nil)
            }
            return nil // Consume the event
        }
        
        // Handle escape key
        if key == String(Character(UnicodeScalar(27)!)) { // Escape
            DispatchQueue.main.async {
                window.orderOut(nil)
            }
            return nil // Consume the event
        }
        
        // Allow Cmd+, for settings
        if key == "," && modifiers.contains(.command) {
            DispatchQueue.main.async {
                self.openSettings()
            }
            return nil // Consume the event
        }
        
        // Block all other keyboard shortcuts when recording window is focused
        if modifiers.contains(.command) {
            return nil // Consume and block the event
        }
        
        // Allow non-command keys to pass through
        return event
    }
    
    func setupHotKey() {
        // Listen for hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateHotKey),
            name: NSNotification.Name("UpdateGlobalHotkey"),
            object: nil
        )
        
        // Listen for settings requests from error dialogs
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSettingsRequested"),
            object: nil
        )
        
        // Listen for welcome completion to setup recording window
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
        
        // Set up initial hotkey
        let savedHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌘⇧Space"
        setupHotKeyFromString(savedHotkey)
    }
    
    @objc func updateHotKey(_ notification: Notification) {
        if let newHotkeyString = notification.object as? String {
            setupHotKeyFromString(newHotkeyString)
        }
    }
    
    private func setupHotKeyFromString(_ hotkeyString: String) {
        // Clear existing hotkey
        hotKey = nil
        
        // Parse the hotkey string and set up new hotkey
        let (key, modifiers) = parseHotkeyString(hotkeyString)
        
        if let key = key {
            hotKey = HotKey(key: key, modifiers: modifiers)
            hotKey?.keyDownHandler = { [weak self] in
                self?.toggleRecordWindow()
            }
        }
    }
    
    private func parseHotkeyString(_ hotkeyString: String) -> (Key?, NSEvent.ModifierFlags) {
        var modifiers: NSEvent.ModifierFlags = []
        var keyString = hotkeyString
        
        // Parse modifiers
        if keyString.contains("⌘") {
            modifiers.insert(.command)
            keyString = keyString.replacingOccurrences(of: "⌘", with: "")
        }
        if keyString.contains("⇧") {
            modifiers.insert(.shift)
            keyString = keyString.replacingOccurrences(of: "⇧", with: "")
        }
        if keyString.contains("⌥") {
            modifiers.insert(.option)
            keyString = keyString.replacingOccurrences(of: "⌥", with: "")
        }
        if keyString.contains("⌃") {
            modifiers.insert(.control)
            keyString = keyString.replacingOccurrences(of: "⌃", with: "")
        }
        
        // Parse key
        let key = stringToKey(keyString)
        
        return (key, modifiers)
    }
    
    private func stringToKey(_ keyString: String) -> Key? {
        switch keyString.uppercased() {
        case "A": return .a
        case "S": return .s
        case "D": return .d
        case "F": return .f
        case "H": return .h
        case "G": return .g
        case "Z": return .z
        case "X": return .x
        case "C": return .c
        case "V": return .v
        case "B": return .b
        case "Q": return .q
        case "W": return .w
        case "E": return .e
        case "R": return .r
        case "Y": return .y
        case "T": return .t
        case "1": return .one
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "6": return .six
        case "5": return .five
        case "=": return .equal
        case "9": return .nine
        case "7": return .seven
        case "-": return .minus
        case "8": return .eight
        case "0": return .zero
        case "]": return .rightBracket
        case "O": return .o
        case "U": return .u
        case "[": return .leftBracket
        case "I": return .i
        case "P": return .p
        case "⏎": return .return
        case "L": return .l
        case "J": return .j
        case "'": return .quote
        case "K": return .k
        case ";": return .semicolon
        case "\\": return .backslash
        case ",": return .comma
        case "/": return .slash
        case "N": return .n
        case "M": return .m
        case ".": return .period
        case "⇥": return .tab
        case "SPACE": return .space
        case "`": return .grave
        case "⌫": return .delete
        case "⎋": return .escape
        case "↑": return .upArrow
        case "↓": return .downArrow
        case "←": return .leftArrow
        case "→": return .rightArrow
        default: return nil
        }
    }
    
    @objc func toggleRecordWindow() {
        // Don't show recorder window during first-run welcome experience
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        if !hasCompletedWelcome {
            return
        }
        
        // Find the recording window by title
        let recordWindow = NSApp.windows.first { window in
            window.title == "AudioWhisper Recording"
        }
        
        if let window = recordWindow {
            if window.isVisible {
                window.orderOut(nil)
                restoreFocusToPreviousApp()
            } else {
                // Remember the currently active app before showing our window
                storePreviousApp()
                
                // Configure window for proper keyboard handling and space management
                window.canHide = false
                window.acceptsMouseMovedEvents = true
                window.isOpaque = false
                window.hasShadow = true
                
                // Force window to appear in current space by resetting collection behavior
                window.orderOut(nil)
                window.collectionBehavior = []
                
                // Force immediate reset and reconfiguration
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    // Reset window level and behavior to force space redetection
                    window.level = .normal
                    
                    // Use more aggressive collection behavior for fullscreen spaces
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
                    
                    // Brief delay, then set final level and show
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        // Use higher window level to ensure it appears over fullscreen apps
                        window.level = .modalPanel
                        
                        // Activate app to ensure we're in right space context
                        NSApp.activate(ignoringOtherApps: true)
                        
                        // Show window in current space with maximum priority
                        window.orderFrontRegardless()
                        window.makeKeyAndOrderFront(nil)
                        
                        // Ensure proper focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            window.makeKey()
                            window.makeFirstResponder(window.contentView)
                        }
                    }
                }
            }
        }
    }
    
    private func storePreviousApp() {
        // Get the frontmost app (excluding ourselves)
        let workspace = NSWorkspace.shared
        if let frontmostApp = workspace.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmostApp
        }
    }
    
    @objc private func restoreFocusToPreviousApp() {
        guard let prevApp = previousApp else { return }
        
        // Small delay to ensure window is hidden first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            prevApp.activate(options: [])
            self.previousApp = nil
        }
    }
    
    @objc func openSettings() {
        // Hide recording window if open
        if let recordWindow = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), recordWindow.isVisible {
            recordWindow.orderOut(nil)
        }
        
        // Find existing settings window
        let settingsWindow = NSApp.windows.first { $0.title == LocalizedStrings.Settings.title }
        
        if let window = settingsWindow {
            // Bring existing window to front and focus
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            // Create new settings window manually since SwiftUI Settings scene is problematic
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = LocalizedStrings.Settings.title
            settingsWindow.level = .floating
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow.center()
            
            // Activate app first, then show window
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
        }
    }
    
    func checkFirstRun() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Check if this is truly the first run - no provider set at all
            let hasExistingProvider = UserDefaults.standard.string(forKey: "transcriptionProvider") != nil
            let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
            
            if !hasExistingProvider && !hasCompletedWelcome {
                // First run - default to LocalWhisper and show welcome dialog
                UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
                self.showWelcomeAndSettings()
            } else if !hasExistingProvider {
                // Provider was somehow reset - default to LocalWhisper
                UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
            }
        }
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
    
    func createMenuBarIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: LocalizedStrings.Accessibility.microphoneIcon)?.withSymbolConfiguration(config)
        image?.isTemplate = true // This makes it adapt to menu bar appearance
        return image ?? NSImage()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in menu bar
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        
        // Cleanup global key monitor
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        
        // Cleanup hotkey
        hotKey = nil
        
        // Clean up any remaining temporary audio files
        cleanupOldTemporaryFiles()
    }
    
    private func cleanupOldTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])
            let audioFiles = files.filter { $0.lastPathComponent.hasPrefix("recording_") && $0.pathExtension == "m4a" }
            
            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
            
            for file in audioFiles {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date, creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                    }
                } catch {
                    Logger.app.error("Failed to clean up file \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            Logger.app.error("Failed to clean up temporary files: \(error.localizedDescription)")
        }
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
