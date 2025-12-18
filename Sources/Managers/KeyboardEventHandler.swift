import Foundation
import AppKit

internal class KeyboardEventHandler {
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private let isTestEnvironment: Bool
    
    init(isTestEnvironment: Bool = NSClassFromString("XCTestCase") != nil) {
        self.isTestEnvironment = isTestEnvironment
        
        // Avoid installing global monitors in tests to prevent flaky AppKit interactions
        if !isTestEnvironment {
            setupGlobalKeyMonitoring()
        }
    }
    
    private func setupGlobalKeyMonitoring() {
        // Use global monitor that works regardless of focus
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            // Check if recording window is visible
            if let window = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), window.isVisible {
                _ = self.handleKeyEvent(event, for: window)
            }
        }
        
        // Also add local monitor with proper filtering
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check if recording window is visible
            if let window = NSApp.windows.first(where: { $0.title == "AudioWhisper Recording" }), window.isVisible {
                // Always consume events when recording window is visible to prevent passthrough
                _ = self.handleKeyEvent(event, for: window)
                return nil // Consume the event to prevent it from reaching other apps
            }
            return event
        }
    }
    
    @discardableResult
    func handleKeyEvent(_ event: NSEvent, for window: NSWindow) -> NSEvent? {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags
        
        // Handle space key
        if key == " " && !modifiers.contains(.command) {
            NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
            return nil // Consume the event
        }
        
        // Handle escape key
        if key == String(Character(UnicodeScalar(27)!)) { // Escape
            NotificationCenter.default.post(name: .escapeKeyPressed, object: nil)
            return nil // Consume the event
        }
        
        // Handle return key
        if key == String(Character(UnicodeScalar(13)!)) || key == "\r" { // Return/Enter
            NotificationCenter.default.post(name: .returnKeyPressed, object: nil)
            return nil // Consume the event
        }
        
        // Allow ⌘, for opening dashboard/settings replacement
        if key == "," && modifiers.contains(.command) {
            Task { @MainActor in
                DashboardWindowManager.shared.showDashboardWindow()
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
    
    deinit {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
