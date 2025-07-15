import Foundation
import AppKit
import SwiftUI
import SwiftData

/// Manages window display and focus restoration for AudioWhisper
/// 
/// This class handles showing/hiding the recording window and restoring focus
/// to the previous application. All window operations now support optional
/// completion handlers for better coordination and testing.
class WindowController {
    private var previousApp: NSRunningApplication?
    private let isTestEnvironment: Bool
    
    // Thread-safe static property to share target app with ContentView
    private static let storedTargetAppQueue = DispatchQueue(label: "com.audiowhisper.storedTargetApp", attributes: .concurrent)
    private static var _storedTargetApp: NSRunningApplication?
    
    static var storedTargetApp: NSRunningApplication? {
        get {
            return storedTargetAppQueue.sync {
                return _storedTargetApp
            }
        }
        set {
            storedTargetAppQueue.async(flags: .barrier) {
                _storedTargetApp = newValue
            }
        }
    }
    
    init() {
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
    }
    
    func toggleRecordWindow(_ window: NSWindow? = nil, completion: (() -> Void)? = nil) {
        // Don't show recorder window during first-run welcome experience
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        if !hasCompletedWelcome {
            completion?()
            return
        }
        
        // Use provided window or find the recording window by title
        let recordWindow = window ?? NSApp.windows.first { window in
            window.title == "AudioWhisper Recording"
        }
        
        if let window = recordWindow {
            if window.isVisible {
                hideWindow(window, completion: completion)
            } else {
                showWindow(window, completion: completion)
            }
        } else {
            completion?()
        }
    }
    
    private func hideWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        window.orderOut(nil)
        restoreFocusToPreviousApp(completion: completion)
    }
    
    private func showWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            completion?()
            return
        }
        
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
        
        // Step 1: Reset and reconfigure window
        performWindowOperation(after: 0.02) { [weak self] in
            guard self != nil else {
                completion?()
                return
            }
            
            // Reset window level and behavior to force space redetection
            window.level = .normal
            
            // Use more aggressive collection behavior for fullscreen spaces
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
            
            // Step 2: Set final level and show window
            self?.performWindowOperation(after: 0.01) { [weak self] in
                guard self != nil else {
                    completion?()
                    return
                }
                
                // Use higher window level to ensure it appears over fullscreen apps
                window.level = .modalPanel
                
                // Activate app to ensure we're in right space context
                NSApp.activate(ignoringOtherApps: true)
                
                // Show window in current space with maximum priority
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                
                // Step 3: Ensure proper focus
                self?.performWindowOperation(after: 0.05) {
                    window.makeKey()
                    window.makeFirstResponder(window.contentView)
                    completion?()
                }
            }
        }
    }
    
    /// Helper method to perform window operations with delays and completion handlers
    private func performWindowOperation(after delay: TimeInterval, operation: @escaping () -> Void) {
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: operation)
        } else {
            DispatchQueue.main.async(execute: operation)
        }
    }
    
    private func storePreviousApp() {
        let workspace = NSWorkspace.shared
        if let frontmostApp = workspace.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmostApp
            WindowController.storedTargetApp = frontmostApp
            
            // Also notify via NotificationCenter as backup
            NotificationCenter.default.post(
                name: .targetAppStored,
                object: frontmostApp
            )
        }
    }
    
    func restoreFocusToPreviousApp(completion: (() -> Void)? = nil) {
        guard let prevApp = previousApp else {
            completion?()
            return
        }
        
        // Small delay to ensure window is hidden first
        performWindowOperation(after: 0.1) { [weak self] in
            prevApp.activate(options: [])
            self?.previousApp = nil
            completion?()
        }
    }
    
    private weak var settingsWindow: NSWindow?
    private var settingsWindowDelegate: SettingsWindowDelegate?
    
    @MainActor func openSettings() {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            return
        }
        
        // Hide recording window if open
        if let recordWindow = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), recordWindow.isVisible {
            recordWindow.orderOut(nil)
        }
        
        // Check if settings window already exists
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            // Bring existing window to front and focus
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
        } else {
            // Create new settings window (SwiftUI Settings scene can have focus issues)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = LocalizedStrings.Settings.title
            window.level = .floating
            
            // Ensure window doesn't cause app to quit when closed
            window.isReleasedWhenClosed = false
            
            // Create SettingsView with proper ModelContainer
            let settingsView = SettingsView()
                .modelContainer(DataManager.shared.sharedModelContainer ?? createFallbackModelContainer())
            
            window.contentView = NSHostingView(rootView: settingsView)
            window.center()
            
            // Set up delegate to handle window lifecycle
            settingsWindowDelegate = SettingsWindowDelegate { [weak self] in
                self?.settingsWindow = nil
                self?.settingsWindowDelegate = nil
            }
            window.delegate = settingsWindowDelegate
            
            // Store weak reference
            settingsWindow = window
            
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
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
}

/// Window delegate that handles the settings window lifecycle
private class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
