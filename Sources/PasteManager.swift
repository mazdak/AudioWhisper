import Foundation
import AppKit
import ApplicationServices
import Carbon

@MainActor
class PasteManager: ObservableObject {
    
    /// Attempts to paste text to the currently active application
    /// Uses CGEvent to simulate Cmd+V 
    func pasteToActiveApp() {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        
        if enableSmartPaste {
            // Use CGEvent to simulate Cmd+V
            performCGEventPaste()
        } else {
            // Just copy to clipboard - user will manually paste
            // Text is already in clipboard from transcription
        }
    }
    
    /// Performs paste with immediate user interaction context
    /// This should work better than automatic pasting
    func pasteWithUserInteraction() {
        // Always request permission with prompt if not granted
        if !checkAccessibilityPermission() {
            let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [checkOptionPrompt: true] as CFDictionary
            let _ = AXIsProcessTrustedWithOptions(options)
            return
        }
        performCGEventPaste()
    }
    
    // MARK: - CGEvent Paste
    
    private func performCGEventPaste() {
        // Check Accessibility permission first (without prompting)
        guard checkAccessibilityPermission() else {
            // Permission not granted - CGEvent won't work
            // macOS will show permission dialog when CGEvent is first used
            return
        }
        
        // Immediate paste with user interaction context
        simulateCmdVPaste()
    }
    
    private func checkAccessibilityPermission() -> Bool {
        // Check without prompting
        let trusted = AXIsProcessTrustedWithOptions(nil)
        return trusted
    }
    
    private func simulateCmdVPaste() {
        // Create event source
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            handlePasteFailure(reason: "Could not create event source")
            return
        }
        
        // Disable local keyboard events while pasting
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        
        // Create Cmd+V key events
        let cmdFlag = CGEventFlags([.maskCommand])
        let vKeyCode = CGKeyCode(kVK_ANSI_V) // V key
        
        // Create key down and key up events
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            handlePasteFailure(reason: "Could not create keyboard events")
            return
        }
        
        // Set Command modifier flag
        keyVDown.flags = cmdFlag
        keyVUp.flags = cmdFlag
        
        // Post the events
        keyVDown.post(tap: .cgSessionEventTap)
        keyVUp.post(tap: .cgSessionEventTap)
    }
    
    private func handlePasteFailure(reason: String) {
        // Post notification to inform UI about paste failure
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("PasteOperationFailed"),
                object: reason
            )
        }
    }
    
}
