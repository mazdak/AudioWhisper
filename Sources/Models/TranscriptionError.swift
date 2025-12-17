import Foundation

/// Represents different types of transcription errors with associated UI properties
internal enum TranscriptionError {
    case missingAPIKey(provider: String)
    case invalidAPIKey(provider: String)
    case microphonePermissionDenied
    case microphonePermissionRestricted
    case microphoneUnavailable
    case networkConnectionError
    case networkTimeout
    case transcriptionFailed(reason: String)
    case audioProcessingError
    case modelNotFound(model: String)
    case insufficientStorage
    case pythonConfigurationError
    case generalError(message: String)
    
    /// Determines the error type from an error message
    static func from(errorMessage: String) -> TranscriptionError {
        let lowercased = errorMessage.lowercased()
        
        // API Key errors
        if lowercased.contains("api key") || lowercased.contains("api_key") || lowercased.contains("apikey") {
            if lowercased.contains("missing") || lowercased.contains("not set") || lowercased.contains("required") {
                let provider = extractProvider(from: errorMessage)
                return .missingAPIKey(provider: provider)
            } else if lowercased.contains("invalid") || lowercased.contains("unauthorized") || lowercased.contains("401") {
                let provider = extractProvider(from: errorMessage)
                return .invalidAPIKey(provider: provider)
            }
        }
        
        // Microphone errors
        if lowercased.contains("microphone") || lowercased.contains("audio input") || lowercased.contains("recording") {
            if lowercased.contains("permission") || lowercased.contains("access") {
                if lowercased.contains("denied") {
                    return .microphonePermissionDenied
                } else if lowercased.contains("restricted") {
                    return .microphonePermissionRestricted
                }
            } else if lowercased.contains("unavailable") || lowercased.contains("not available") {
                return .microphoneUnavailable
            }
        }
        
        // Network errors
        if lowercased.contains("network") || lowercased.contains("connection") || lowercased.contains("internet") {
            if lowercased.contains("timeout") {
                return .networkTimeout
            }
            return .networkConnectionError
        }
        
        // Model errors
        if lowercased.contains("model") && (lowercased.contains("not found") || lowercased.contains("missing")) {
            let model = extractModel(from: errorMessage)
            return .modelNotFound(model: model)
        }
        
        // Storage errors
        if lowercased.contains("storage") || lowercased.contains("disk space") || lowercased.contains("insufficient") {
            return .insufficientStorage
        }
        
        // Python errors
        if lowercased.contains("python") || lowercased.contains("parakeet") {
            return .pythonConfigurationError
        }
        
        // Audio processing errors
        if lowercased.contains("audio") && (lowercased.contains("process") || lowercased.contains("convert")) {
            return .audioProcessingError
        }
        
        // Transcription errors
        if lowercased.contains("transcription") || lowercased.contains("whisper") || lowercased.contains("gemini") {
            return .transcriptionFailed(reason: errorMessage)
        }
        
        // Default to general error
        return .generalError(message: errorMessage)
    }
    
    /// The primary button title for this error type
    var primaryButtonTitle: String {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            return "Open Settings"
        case .microphonePermissionDenied, .microphonePermissionRestricted:
            return "Open System Settings"
        case .microphoneUnavailable, .networkConnectionError, .networkTimeout,
             .audioProcessingError, .transcriptionFailed, .generalError:
            return "OK"
        case .modelNotFound:
            return "Download Model"
        case .insufficientStorage:
            return "Manage Storage"
        case .pythonConfigurationError:
            return "Configure Python"
        }
    }
    
    /// The secondary button title (if applicable)
    var secondaryButtonTitle: String? {
        switch self {
        case .missingAPIKey, .invalidAPIKey, .microphonePermissionDenied,
             .microphonePermissionRestricted, .modelNotFound, .pythonConfigurationError:
            return "Cancel"
        default:
            return nil
        }
    }
    
    /// Whether this error should show a settings button
    var shouldShowSettingsButton: Bool {
        switch self {
        case .missingAPIKey, .invalidAPIKey, .modelNotFound, .pythonConfigurationError:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error should show system settings button
    var shouldShowSystemSettingsButton: Bool {
        switch self {
        case .microphonePermissionDenied, .microphonePermissionRestricted:
            return true
        default:
            return false
        }
    }
    
    /// A user-friendly error message
    var userMessage: String {
        switch self {
        case .missingAPIKey(let provider):
            return "\(provider) API key is required. Please add your API key in Settings."
        case .invalidAPIKey(let provider):
            return "Invalid \(provider) API key. Please check your API key in Settings."
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please grant permission in System Settings > Privacy & Security > Microphone."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted. Please check System Settings > Privacy & Security > Microphone."
        case .microphoneUnavailable:
            return "No microphone available. Please connect a microphone and try again."
        case .networkConnectionError:
            return "Network connection error. Please check your internet connection and try again."
        case .networkTimeout:
            return "Request timed out. Please check your connection and try again."
        case .transcriptionFailed(let reason):
            return reason
        case .audioProcessingError:
            return "Failed to process audio. Please try recording again."
        case .modelNotFound(let model):
            return "Model '\(model)' not found. Please download it in Settings."
        case .insufficientStorage:
            return "Insufficient storage space. Please free up some space and try again."
        case .pythonConfigurationError:
            return "Python configuration error. Please check your Python path and ensure parakeet-mlx is installed."
        case .generalError(let message):
            return message
        }
    }
    
    /// Helper to extract provider name from error message
    private static func extractProvider(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("openai") {
            return "OpenAI"
        } else if lowercased.contains("gemini") || lowercased.contains("google") {
            return "Gemini"
        } else if lowercased.contains("whisper") {
            return "Whisper"
        } else if lowercased.contains("parakeet") {
            return "Parakeet"
        }
        return "API"
    }
    
    /// Helper to extract model name from error message
    private static func extractModel(from message: String) -> String {
        // Try to extract model name from common patterns
        if let range = message.range(of: "model '([^']+)'", options: .regularExpression) {
            let modelPart = String(message[range])
            return modelPart.replacingOccurrences(of: "model '", with: "").replacingOccurrences(of: "'", with: "")
        }
        
        // Look for common model names
        let models = ["tiny", "base", "small", "medium", "large", "turbo"]
        let lowercased = message.lowercased()
        for model in models {
            if lowercased.contains(model) {
                return model.capitalized
            }
        }
        
        return "Unknown"
    }
}