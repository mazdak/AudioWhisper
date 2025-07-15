import SwiftUI
import AppKit
import os.log

@MainActor
class ErrorPresenter {
    static let shared = ErrorPresenter()
    
    // Thread-safe properties with proper synchronization
    private let queue = DispatchQueue(label: "com.audiowhisper.errorpresenter", qos: .userInitiated)
    private var _isTestEnvironment: Bool = false
    
    // Cached lowercased error patterns for efficient matching
    private let errorPatterns: [String: [String]] = [
        "api_key": ["api key"],
        "microphone": ["microphone", "permission"],
        "connection": ["internet", "connection"],
        "transcription": ["transcription"]
    ]
    
    // Logger for security and debugging
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ErrorPresenter")
    
    var isTestEnvironment: Bool {
        get {
            return queue.sync { _isTestEnvironment }
        }
        set {
            queue.sync { _isTestEnvironment = newValue }
        }
    }
    
    private init() {
        // Detect if running in tests - thread-safe initialization
        queue.sync {
            _isTestEnvironment = NSClassFromString("XCTestCase") != nil
        }
    }
    
    func showError(_ message: String) {
        // Sanitize input to prevent sensitive data leakage
        let sanitizedMessage = sanitizeErrorMessage(message)
        
        // Log error for debugging (sanitized version)
        logger.error("Error presented: \(sanitizedMessage, privacy: .public)")
        
        // Ensure we're on the main thread for UI operations
        Task { @MainActor in
            await showAlertOnMainThread(sanitizedMessage)
        }
    }
    
    // MARK: - Input Sanitization
    
    private func sanitizeErrorMessage(_ message: String) -> String {
        var sanitized = message
        
        // Remove potential API keys (common patterns)
        sanitized = sanitized.replacingOccurrences(
            of: "\\b[A-Za-z0-9]{20,}\\b",
            with: "[REDACTED_API_KEY]",
            options: .regularExpression
        )
        
        // Remove potential file paths containing user information
        sanitized = sanitized.replacingOccurrences(
            of: "/Users/[^/\\s]+",
            with: "/Users/[USER]",
            options: .regularExpression
        )
        
        // Remove potential IP addresses
        sanitized = sanitized.replacingOccurrences(
            of: "\\b(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\\b",
            with: "[REDACTED_IP]",
            options: .regularExpression
        )
        
        // Remove potential email addresses
        sanitized = sanitized.replacingOccurrences(
            of: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b",
            with: "[REDACTED_EMAIL]",
            options: .regularExpression
        )
        
        // Truncate if too long to prevent memory issues
        let maxLength = 500
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength)) + "... [MESSAGE_TRUNCATED]"
        }
        
        return sanitized
    }
    
    // MARK: - Error Pattern Matching
    
    private func getErrorType(from message: String) -> String? {
        let lowercasedMessage = message.lowercased()
        
        for (errorType, patterns) in errorPatterns {
            if patterns.contains(where: { lowercasedMessage.contains($0) }) {
                return errorType
            }
        }
        
        return nil
    }
    
    private func showAlertOnMainThread(_ message: String) async {
        // Skip UI operations in test environment
        if isTestEnvironment {
            // In tests, just handle the error classification
            await handleTestErrorResponse(for: message)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = LocalizedStrings.Alerts.errorTitle
        alert.informativeText = message
        alert.alertStyle = .critical
        
        // Add OK button (default)
        alert.addButton(withTitle: "OK")
        
        // Add contextual buttons based on error type using efficient pattern matching
        let errorType = getErrorType(from: message)
        
        switch errorType {
        case "api_key":
            alert.addButton(withTitle: "Open Settings")
        case "microphone":
            alert.addButton(withTitle: "Open System Settings")
        case "connection":
            alert.addButton(withTitle: "Try Again")
        case "transcription":
            // For transcription errors, offer retry and reveal audio file
            alert.addButton(withTitle: "Try Again")
            alert.addButton(withTitle: "Show Audio File")
        default:
            // No additional buttons for unknown error types
            break
        }
        
        // Show alert without blocking UI across Spaces
        let response = alert.runModal()
        
        // Handle button responses
        await handleErrorResponse(response, for: message, errorType: errorType)
    }
    
    private func handleTestErrorResponse(for message: String) async {
        // In tests, simulate the second button click based on message type
        let errorType = getErrorType(from: message)
        
        switch errorType {
        case "api_key":
            NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        case "microphone":
            // Skip actual system settings in tests
            break
        case "connection":
            NotificationCenter.default.post(name: .retryRequested, object: nil)
        case "transcription":
            NotificationCenter.default.post(name: .retryTranscriptionRequested, object: nil)
        default:
            // No action for unknown error types in tests
            break
        }
    }
    
    private func handleErrorResponse(_ response: NSApplication.ModalResponse, for message: String, errorType: String?) async {
        switch response {
        case .alertSecondButtonReturn:
            switch errorType {
            case "api_key":
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            case "microphone":
                await openSystemSettings()
            case "connection":
                NotificationCenter.default.post(name: .retryRequested, object: nil)
            case "transcription":
                NotificationCenter.default.post(name: .retryTranscriptionRequested, object: nil)
            default:
                // No action for unknown error types
                break
            }
        case .alertThirdButtonReturn:
            // Handle third button (Show Audio File) for transcription errors
            if errorType == "transcription" {
                NotificationCenter.default.post(name: .showAudioFileRequested, object: nil)
            }
        default:
            // Handle other responses (OK button, etc.)
            break
        }
    }
    
    private func openSystemSettings() async {
        // Skip opening system settings in test environment
        if isTestEnvironment {
            return
        }
        
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            logger.error("Failed to create system settings URL")
            return
        }
        
        let success = NSWorkspace.shared.open(url)
        if !success {
            logger.error("Failed to open system settings")
        }
    }
}