import Foundation
import AppKit

class KeyboardEventHandler {
    private var globalKeyMonitor: Any?
    
    init() {
        setupGlobalKeyMonitoring()
    }
    
    private func setupGlobalKeyMonitoring() {
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
                // Always consume events when recording window is visible to prevent passthrough
                _ = self.handleKeyEvent(event, for: window)
                return nil // Consume the event to prevent it from reaching other apps
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
                NotificationCenter.default.post(name: NSNotification.Name("EscapeKeyPressed"), object: nil)
            }
            return nil // Consume the event
        }
        
        // Allow Cmd+, for settings
        if key == "," && modifiers.contains(.command) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsRequested"), object: nil)
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
    }
}