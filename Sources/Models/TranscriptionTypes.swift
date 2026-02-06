import Foundation

internal enum WhisperModelError: Error, LocalizedError, Sendable {
    case invalidURL(fileName: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let fileName):
            return "Invalid URL for whisper model file: \(fileName)"
        }
    }
}

internal enum TranscriptionProvider: String, CaseIterable, Codable, Sendable {
    case openai = "openai"
    case gemini = "gemini" 
    case local = "local"
    case parakeet = "parakeet"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI Whisper (Cloud)"
        case .gemini:
            return "Google Gemini (Cloud)"
        case .local:
            return "Whisper (Local)"
        case .parakeet:
            return "Parakeet (Advanced)"
        }
    }
}

internal enum WhisperModel: String, CaseIterable, Codable, Sendable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case largeTurbo = "large-v3-turbo"

    var displayName: String {
        switch self {
        case .tiny:
            return "Tiny (39MB)"
        case .base:
            return "Base (142MB)"
        case .small:
            return "Small (466MB)"
        case .largeTurbo:
            return "Large Turbo (1.5GB)"
        }
    }

    var fileSize: String {
        switch self {
        case .tiny:
            return "39MB"
        case .base:
            return "142MB"
        case .small:
            return "466MB"
        case .largeTurbo:
            return "1.5GB"
        }
    }

    var fileName: String {
        return "ggml-\(rawValue).bin"
    }

    var downloadURL: URL {
        // Safe fallback version - returns base model URL if current model URL is invalid
        do {
            return try getDownloadURL()
        } catch {
            // Fallback to base model if there's an issue with the current model URL
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!
        }
    }

    func getDownloadURL() throws -> URL {
        guard let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)") else {
            throw WhisperModelError.invalidURL(fileName: fileName)
        }
        return url
    }

    var description: String {
        switch self {
        case .tiny:
            return "Fastest, basic accuracy"
        case .base:
            return "Good balance of speed and accuracy"
        case .small:
            return "Better accuracy, reasonable speed"
        case .largeTurbo:
            return "Highest accuracy, optimized for speed"
        }
    }
}

internal enum ParakeetModel: String, CaseIterable, Codable, Sendable {
    case v2English = "mlx-community/parakeet-tdt-0.6b-v2"
    case v3Multilingual = "mlx-community/parakeet-tdt-0.6b-v3"

    var displayName: String {
        switch self {
        case .v2English:
            return "v2 English (~2.5 GB)"
        case .v3Multilingual:
            return "v3 Multilingual (~2.5 GB)"
        }
    }

    var description: String {
        switch self {
        case .v2English:
            return "English only, original model"
        case .v3Multilingual:
            return "25 languages, auto-detection"
        }
    }

    var repoId: String {
        rawValue
    }
}
