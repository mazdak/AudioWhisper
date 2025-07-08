import Foundation
import Alamofire
import os.log

enum SpeechToTextError: Error, LocalizedError {
    case invalidURL
    case apiKeyMissing(String)
    case transcriptionFailed(String)
    case localTranscriptionFailed(Error)
    case fileTooLarge
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return LocalizedStrings.Errors.invalidAudioFile
        case .apiKeyMissing(let provider):
            return String(format: LocalizedStrings.Errors.apiKeyMissing, provider)
        case .transcriptionFailed(let message):
            return String(format: LocalizedStrings.Errors.transcriptionFailed, message)
        case .localTranscriptionFailed(let error):
            return String(format: LocalizedStrings.Errors.localTranscriptionFailed, error.localizedDescription)
        case .fileTooLarge:
            return LocalizedStrings.Errors.fileTooLarge
        }
    }
}

class SpeechToTextService: ObservableObject {
    private let localWhisperService = LocalWhisperService()
    private let keychainService: KeychainServiceProtocol
    
    init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.keychainService = keychainService
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        let useOpenAI = UserDefaults.standard.bool(forKey: "useOpenAI")
        if useOpenAI != false { // Default to OpenAI if not set
            return try await transcribeWithOpenAI(audioURL: audioURL)
        } else {
            return try await transcribeWithGemini(audioURL: audioURL)
        }
    }
    
    func transcribe(audioURL: URL, provider: TranscriptionProvider, model: WhisperModel? = nil) async throws -> String {
        // Validate audio file before processing
        let validationResult = await AudioValidator.validateAudioFile(at: audioURL)
        switch validationResult {
        case .valid(_):
            break // Audio file validated successfully
        case .invalid(let error):
            throw SpeechToTextError.transcriptionFailed(error.localizedDescription)
        }
        
        switch provider {
        case .openai:
            return try await transcribeWithOpenAI(audioURL: audioURL)
        case .gemini:
            return try await transcribeWithGemini(audioURL: audioURL)
        case .local:
            guard let model = model else {
                throw SpeechToTextError.transcriptionFailed("Whisper model required for local transcription")
            }
            return try await transcribeWithLocal(audioURL: audioURL, model: model)
        }
    }
    
    private func transcribeWithOpenAI(audioURL: URL) async throws -> String {
        // Get API key from keychain
        guard let apiKey = keychainService.getQuietly(service: "AudioWhisper", account: "OpenAI") else {
            throw SpeechToTextError.apiKeyMissing("OpenAI")
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(audioURL, withName: "file")
                    multipartFormData.append("whisper-1".data(using: .utf8)!, withName: "model")
                },
                to: "https://api.openai.com/v1/audio/transcriptions",
                headers: headers
            )
            .responseDecodable(of: WhisperResponse.self) { response in
                switch response.result {
                case .success(let whisperResponse):
                    let cleanedText = Self.cleanTranscriptionText(whisperResponse.text)
                    continuation.resume(returning: cleanedText)
                case .failure(let error):
                    continuation.resume(throwing: SpeechToTextError.transcriptionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func transcribeWithGemini(audioURL: URL) async throws -> String {
        // Get API key from keychain
        guard let apiKey = keychainService.getQuietly(service: "AudioWhisper", account: "Gemini") else {
            throw SpeechToTextError.apiKeyMissing("Gemini")
        }
        
        // Check file size to decide on upload method
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // Use Files API for larger files (>10MB) to avoid memory issues
        if fileSize > 10 * 1024 * 1024 {
            return try await transcribeWithGeminiFilesAPI(audioURL: audioURL, apiKey: apiKey)
        } else {
            return try await transcribeWithGeminiInline(audioURL: audioURL, apiKey: apiKey)
        }
    }
    
    private func transcribeWithGeminiFilesAPI(audioURL: URL, apiKey: String) async throws -> String {
        // First, upload the file using Files API
        let fileUploadURL = "https://generativelanguage.googleapis.com/upload/v1beta/files"
        
        let uploadHeaders: HTTPHeaders = [
            "X-Goog-Api-Key": apiKey
        ]
        
        // Upload file using multipart form data
        let uploadedFile = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GeminiFileResponse, Error>) in
            AF.upload(
                multipartFormData: { multipartFormData in
                    multipartFormData.append(audioURL, withName: "file")
                    let metadata = ["file": ["display_name": "audio_recording"]]
                    if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
                        multipartFormData.append(metadataData, withName: "metadata", mimeType: "application/json")
                    }
                },
                to: fileUploadURL,
                headers: uploadHeaders
            )
            .responseDecodable(of: GeminiFileResponse.self) { response in
                switch response.result {
                case .success(let fileResponse):
                    continuation.resume(returning: fileResponse)
                case .failure(let error):
                    continuation.resume(throwing: SpeechToTextError.transcriptionFailed("File upload failed: \(error.localizedDescription)"))
                }
            }
        }
        
        // Now use the uploaded file for transcription
        let transcriptionURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
        
        let headers: HTTPHeaders = [
            "X-Goog-Api-Key": apiKey,
            "Content-Type": "application/json"
        ]
        
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "file_data": [
                        "mime_type": "audio/mp4",
                        "file_uri": uploadedFile.file.uri
                    ]
                ], [
                    "text": "Transcribe this audio to text. Return only the transcription without any additional text."
                ]]
            ]]
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(transcriptionURL, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
                .responseDecodable(of: GeminiResponse.self) { response in
                    switch response.result {
                    case .success(let geminiResponse):
                        if let text = geminiResponse.candidates.first?.content.parts.first?.text {
                            let cleanedText = Self.cleanTranscriptionText(text)
                            continuation.resume(returning: cleanedText)
                        } else {
                            continuation.resume(throwing: SpeechToTextError.transcriptionFailed("No text in response"))
                        }
                    case .failure(let error):
                        continuation.resume(throwing: SpeechToTextError.transcriptionFailed(error.localizedDescription))
                    }
                }
        }
    }
    
    private func transcribeWithGeminiInline(audioURL: URL, apiKey: String) async throws -> String {
        // For smaller files, use inline data to avoid the extra upload step
        // Double-check file size for safety
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // Enforce stricter memory limit for inline processing
        if fileSize > 5 * 1024 * 1024 { // 5MB limit
            throw SpeechToTextError.fileTooLarge
        }
        
        let audioData = try Data(contentsOf: audioURL)
        
        // Use autoreleasepool to manage memory pressure
        let base64Audio = autoreleasepool {
            return audioData.base64EncodedString()
        }
        
        let url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
        
        let headers: HTTPHeaders = [
            "X-Goog-Api-Key": apiKey,
            "Content-Type": "application/json"
        ]
        
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "inline_data": [
                        "mime_type": "audio/mp4",
                        "data": base64Audio
                    ]
                ], [
                    "text": "Transcribe this audio to text. Return only the transcription without any additional text."
                ]]
            ]]
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
                .responseDecodable(of: GeminiResponse.self) { response in
                    switch response.result {
                    case .success(let geminiResponse):
                        if let text = geminiResponse.candidates.first?.content.parts.first?.text {
                            let cleanedText = Self.cleanTranscriptionText(text)
                            continuation.resume(returning: cleanedText)
                        } else {
                            continuation.resume(throwing: SpeechToTextError.transcriptionFailed("No text in response"))
                        }
                    case .failure(let error):
                        continuation.resume(throwing: SpeechToTextError.transcriptionFailed(error.localizedDescription))
                    }
                }
        }
    }
    
    private func transcribeWithLocal(audioURL: URL, model: WhisperModel) async throws -> String {
        do {
            let text = try await localWhisperService.transcribe(audioFileURL: audioURL, model: model) { progress in
                NotificationCenter.default.post(name: NSNotification.Name("TranscriptionProgress"), object: progress)
            }
            return Self.cleanTranscriptionText(text)
        } catch {
            throw SpeechToTextError.localTranscriptionFailed(error)
        }
    }
    
    // MARK: - Text Cleaning
    
    /// Cleans transcription text by removing common markers and artifacts
    static func cleanTranscriptionText(_ text: String) -> String {
        var cleanedText = text
        
        // Remove bracketed markers iteratively to handle nested cases
        var previousLength = 0
        while cleanedText.count != previousLength {
            previousLength = cleanedText.count
            cleanedText = cleanedText.replacingOccurrences(
                of: "\\[[^\\[\\]]*\\]",
                with: "",
                options: .regularExpression
            )
        }
        
        // Remove parenthetical markers iteratively to handle nested cases
        previousLength = 0
        while cleanedText.count != previousLength {
            previousLength = cleanedText.count
            cleanedText = cleanedText.replacingOccurrences(
                of: "\\([^\\(\\)]*\\)",
                with: "",
                options: .regularExpression
            )
        }
        
        // Clean up whitespace and return
        return cleanedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
}

// Response models
struct WhisperResponse: Codable {
    let text: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
}

struct GeminiFileResponse: Codable {
    let file: GeminiFile
}

struct GeminiFile: Codable {
    let uri: String
    let name: String
}
