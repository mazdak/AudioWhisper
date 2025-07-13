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
    private var hotKeyManager: HotKeyManager?
    private var keyboardEventHandler: KeyboardEventHandler?
    private var windowController = WindowController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup app configuration
        AppSetupHelper.setupApp()
        
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
            self?.toggleRecordWindow()
        }
        keyboardEventHandler = KeyboardEventHandler()
        
        // Setup additional notification observers
        setupNotificationObservers()
        
        // Hide recording window initially (it will show when hotkey is pressed)
        DispatchQueue.main.async {
            let recordWindow = NSApp.windows.first { window in
                window.title == "AudioWhisper Recording"
            }
            recordWindow?.orderOut(nil)
        }

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
    
    @objc func toggleRecordWindow() {
        windowController.toggleRecordWindow()
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
