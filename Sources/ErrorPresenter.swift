import SwiftUI
import AppKit

class ErrorPresenter {
    static let shared = ErrorPresenter()
    
    // Allow injection for testing
    var isTestEnvironment: Bool = false
    
    private init() {
        // Detect if running in tests
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
    }
    
    func showError(_ message: String) {
        // Ensure we're on the main thread for UI operations
        if Thread.isMainThread {
            showAlertOnMainThread(message)
        } else {
            DispatchQueue.main.async {
                self.showAlertOnMainThread(message)
            }
        }
    }
    
    private func showAlertOnMainThread(_ message: String) {
        // Skip UI operations in test environment
        if isTestEnvironment {
            // In tests, just handle the error classification
            handleTestErrorResponse(for: message)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = LocalizedStrings.Alerts.errorTitle
        alert.informativeText = message
        alert.alertStyle = .critical
        
        // Add OK button (default)
        alert.addButton(withTitle: "OK")
        
        // Add contextual buttons based on error type
        if message.contains("API key") {
            alert.addButton(withTitle: "Open Settings")
        } else if message.contains("microphone") || message.contains("permission") {
            alert.addButton(withTitle: "Open System Settings")
        } else if message.contains("internet") || message.contains("connection") {
            alert.addButton(withTitle: "Try Again")
        }
        
        // Show alert without blocking UI across Spaces
        let response = alert.runModal()
        
        // Handle button responses
        handleErrorResponse(response, for: message)
    }
    
    private func handleTestErrorResponse(for message: String) {
        // In tests, simulate the second button click based on message type
        if message.contains("API key") {
            NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsRequested"), object: nil)
        } else if message.contains("microphone") || message.contains("permission") {
            // Skip actual system settings in tests
        } else if message.contains("internet") || message.contains("connection") {
            NotificationCenter.default.post(name: NSNotification.Name("RetryRequested"), object: nil)
        }
    }
    
    private func handleErrorResponse(_ response: NSApplication.ModalResponse, for message: String) {
        if response == .alertSecondButtonReturn {
            if message.contains("API key") {
                NotificationCenter.default.post(name: NSNotification.Name("OpenSettingsRequested"), object: nil)
            } else if message.contains("microphone") || message.contains("permission") {
                openSystemSettings()
            } else if message.contains("internet") || message.contains("connection") {
                NotificationCenter.default.post(name: NSNotification.Name("RetryRequested"), object: nil)
            }
        }
    }
    
    private func openSystemSettings() {
        // Skip opening system settings in test environment
        if isTestEnvironment {
            return
        }
        
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}