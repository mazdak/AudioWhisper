import Foundation
import AppKit
import ApplicationServices

@MainActor
class PasteManager: ObservableObject {
    
    /// Attempts to paste text to the currently active application
    /// Uses smart accessibility-based pasting with fallback to Cmd+V
    func pasteToActiveApp() {
        Task {
            let success = await trySmartPaste()
            if !success {
                await fallbackToCmdV()
            }
        }
    }
    
    // MARK: - Smart Accessibility Pasting
    
    private func trySmartPaste() async -> Bool {
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        // Skip if AudioWhisper is the frontmost app (shouldn't happen but safety check)
        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }
        
        // Get the process ID of the frontmost app
        let pid = frontmostApp.processIdentifier
        
        // Create AXUIElement for the frontmost application
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to find and paste to the focused text field
        do {
            let success = try await pasteToFocusedTextField(appElement: appElement)
            return success
        } catch {
            // If accessibility fails, return false to trigger fallback
            return false
        }
    }
    
    private func pasteToFocusedTextField(appElement: AXUIElement) async throws -> Bool {
        // Get the focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let focused = focusedElement else {
            return false
        }
        
        // Safely cast to AXUIElement after type check
        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return false
        }
        let axElement = unsafeBitCast(focused, to: AXUIElement.self)
        
        // Check if the focused element is a text field or text area
        if try isTextInputElement(axElement) {
            // Get current clipboard content
            guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
                return false
            }
            
            // Try to set the value directly using accessibility
            let success = try setTextValue(element: axElement, text: clipboardString)
            if success {
                return true
            }
        }
        
        return false
    }
    
    private func isTextInputElement(_ element: AXUIElement) throws -> Bool {
        // Check the role of the element
        var roleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        
        guard result == .success, let role = roleValue as? String else {
            return false
        }
        
        // Check if it's a text input element
        let textInputRoles: Set<String> = [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole,
            "AXSearchField"
        ]
        
        return textInputRoles.contains(role)
    }
    
    private func setTextValue(element: AXUIElement, text: String) throws -> Bool {
        // First, try to select all existing text
        let _ = AXUIElementPerformAction(element, "AXSelectAll" as CFString)
        
        // Then try to set the value
        let setValue = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        
        if setValue == .success {
            return true
        }
        
        // If direct value setting fails, try using the focused element's insert action
        let insertResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        
        return insertResult == .success
    }
    
    // MARK: - Fallback Cmd+V Simulation
    
    private func fallbackToCmdV() async {
        // Add a small delay to ensure the window focus changes properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.simulateCmdV()
        }
    }
    
    private func simulateCmdV() {
        // Simulate Cmd+V to paste
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            return
        }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cghidEventTap)
    }
}