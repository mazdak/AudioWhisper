import Foundation
import AppKit
import SwiftUI

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
        // Detect if running in tests
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
    }
    
    func toggleRecordWindow(_ window: NSWindow? = nil) {
        // Don't show recorder window during first-run welcome experience
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        if !hasCompletedWelcome {
            return
        }
        
        // Use provided window or find the recording window by title
        let recordWindow = window ?? NSApp.windows.first { window in
            window.title == "AudioWhisper Recording"
        }
        
        if let window = recordWindow {
            if window.isVisible {
                hideWindow(window)
            } else {
                showWindow(window)
            }
        }
    }
    
    private func hideWindow(_ window: NSWindow) {
        window.orderOut(nil)
        restoreFocusToPreviousApp()
    }
    
    private func showWindow(_ window: NSWindow) {
        // Skip actual window operations in test environment
        if isTestEnvironment {
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
    
    private func storePreviousApp() {
        // Get the frontmost app (excluding ourselves)
        let workspace = NSWorkspace.shared
        if let frontmostApp = workspace.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmostApp
            WindowController.storedTargetApp = frontmostApp  // Store in static property
            
            // Also notify via NotificationCenter as backup
            NotificationCenter.default.post(
                name: NSNotification.Name("TargetAppStored"),
                object: frontmostApp
            )
        }
    }
    
    func restoreFocusToPreviousApp() {
        guard let prevApp = previousApp else { return }
        
        // Small delay to ensure window is hidden first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            prevApp.activate(options: [])
            self.previousApp = nil
        }
    }
    
    func openSettings() {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            return
        }
        
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
}
