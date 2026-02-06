import Foundation
import Alamofire

import os.log

internal final class SemanticCorrectionService {
    private let mlxService = MLXCorrectionService()
    private let keychainService: KeychainServiceProtocol
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "SemanticCorrection")
    
    // Chunking configuration for 32k context window
    // 32k tokens ≈ 24k words (0.75 ratio) ≈ 120k chars
    // Use conservative 6k words to leave room for system prompt
    private static let chunkSizeWords = 6000
    private static let overlapSizeWords = 200 // Small overlap for context continuity
    
    private func categoryFor(bundleId: String?) -> CategoryDefinition {
        guard let id = bundleId else { return CategoryDefinition.fallback }
        return AppCategoryManager.shared.category(for: id)
    }

    init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.keychainService = keychainService
    }

    func correct(text: String, providerUsed: TranscriptionProvider, sourceAppBundleId: String? = nil) async -> String {
        let outcome = await correctWithWarning(text: text, providerUsed: providerUsed, sourceAppBundleId: sourceAppBundleId)
        return outcome.text
    }

    /// Like `correct(...)`, but returns a warning string when semantic correction is enabled but cannot run.
    ///
    /// This is used by the recording UI to reduce "silent failure" confusion for local MLX correction.
    func correctWithWarning(text: String, providerUsed: TranscriptionProvider, sourceAppBundleId: String? = nil) async -> (text: String, warning: String?) {
        let modeRaw = UserDefaults.standard.string(forKey: AppDefaults.Keys.semanticCorrectionMode) ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        let category = categoryFor(bundleId: sourceAppBundleId)
        logger.info("Correction category: \(category.id) for bundleId: \(sourceAppBundleId ?? "nil")")
        
        switch mode {
        case .off:
            return (text, nil)
        case .localMLX:
            // Allow local MLX correction regardless of STT provider
            logger.info("Running local MLX correction")
            return await correctLocallyWithMLX(text: text, category: category)
        case .cloud:
            switch providerUsed {
            case .openai:
                logger.info("Running cloud correction: OpenAI")
                return (await correctWithOpenAI(text: text, category: category), nil)
            case .gemini:
                logger.info("Running cloud correction: Gemini")
                return (await correctWithGemini(text: text, category: category), nil)
            case .local, .parakeet:
                // Don't send local text to cloud.
                return (text, nil)
            }
        }
    }

    // MARK: - Local (MLX)
    private func correctLocallyWithMLX(text: String, category: CategoryDefinition) async -> (text: String, warning: String?) {
        guard Arch.isAppleSilicon else {
            return (text, "Local semantic correction requires an Apple Silicon Mac.")
        }
        let modelRepo = UserDefaults.standard.string(forKey: AppDefaults.Keys.semanticCorrectionModelRepo) ?? AppDefaults.defaultSemanticCorrectionModelRepo
        do {
            let pyURL = try UvBootstrap.ensureVenv(userPython: nil)
            let prompt = loadPrompt(for: category)
            let output = try await mlxService.correct(text: text, modelRepo: modelRepo, pythonPath: pyURL.path, systemPrompt: prompt)
            let merged = Self.safeMerge(original: text, corrected: output, maxChangeRatio: 0.6)
            if merged == text {
                logger.info("MLX correction produced no accepted change (kept original)")
            } else {
                logger.info("MLX correction applied changes")
            }
            return (merged, nil)
        } catch {
            logger.error("MLX correction failed: \(error.localizedDescription)")
            return (text, "Semantic correction unavailable (Local MLX). Open Settings → Providers to install dependencies and download the model.")
        }
    }

    // MARK: - Cloud (OpenAI)
    private func correctWithOpenAI(text: String, category: CategoryDefinition) async -> String {
        guard let apiKey = keychainService.getQuietly(service: "AudioWhisper", account: "OpenAI") else {
            return text
        }
        let prompt = loadPrompt(for: category)
        let url = "https://api.openai.com/v1/chat/completions"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        let body: [String: Any] = [
            "model": "gpt-5.1-mini",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_completion_tokens": 8192
        ]

        do {
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
                    .responseDecodable(of: OpenAIChatResponse.self) { response in
                        switch response.result {
                        case .success(let r):
                            let content = r.choices.first?.message.content ?? text
                            cont.resume(returning: content)
                        case .failure(let err):
                            cont.resume(throwing: err)
                        }
                    }
            }
            return Self.safeMerge(original: text, corrected: result, maxChangeRatio: 0.25)
        } catch {
            return text
        }
    }

    // MARK: - Cloud (Gemini)
    private var geminiBaseURL: String {
        let custom = UserDefaults.standard.string(forKey: "geminiBaseURL") ?? ""
        if custom.isEmpty {
            return "https://generativelanguage.googleapis.com"
        }
        return custom.hasSuffix("/") ? String(custom.dropLast()) : custom
    }

    private func correctWithGemini(text: String, category: CategoryDefinition) async -> String {
        guard let apiKey = keychainService.getQuietly(service: "AudioWhisper", account: "Gemini") else {
            return text
        }
        let url = "\(geminiBaseURL)/v1beta/models/gemini-2.5-flash-lite:generateContent"
        let headers: HTTPHeaders = [
            "X-Goog-Api-Key": apiKey,
            "Content-Type": "application/json"
        ]
        let prompt = loadPrompt(for: category)
        let body: [String: Any] = [
            "contents": [[
                "parts": [[
                    "text": "\(prompt)\n\n\(text)"
                ]]
            ]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 8192  // Standardized limit
            ]
        ]
        do {
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
                    .responseDecodable(of: GeminiResponse.self) { response in
                        switch response.result {
                        case .success(let r):
                            let content = r.candidates.first?.content.parts.first?.text ?? text
                            cont.resume(returning: content)
                        case .failure(let err):
                            cont.resume(throwing: err)
                        }
                    }
            }
            return Self.safeMerge(original: text, corrected: result, maxChangeRatio: 0.25)
        } catch {
            return text
        }
    }

    // MARK: - Prompt file helpers
    private func promptsBaseDir() -> URL? {
        return try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioWhisper/prompts", isDirectory: true)
    }
    
    private func loadPrompt(for category: CategoryDefinition) -> String {
        // First try user-customized prompt file
        if let base = promptsBaseDir() {
            let url = base.appendingPathComponent("\(category.id)_prompt.txt")
            if let userPrompt = try? String(contentsOf: url, encoding: .utf8), !userPrompt.isEmpty {
                return userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        let trimmed = category.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return CategoryDefinition.fallback.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readPromptFile(name: String) -> String? {
        guard let base = promptsBaseDir() else { return nil }
        let url = base.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Safety Guard (internal for testability)
    static func safeMerge(original: String, corrected: String, maxChangeRatio: Double) -> String {
        guard !corrected.isEmpty else { return original }
        let ratio = normalizedEditDistance(a: original, b: corrected)
        if ratio > maxChangeRatio { return original }
        return corrected.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedEditDistance(a: String, b: String) -> Double {
        if a == b { return 0 }
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 || n == 0 { return 1 }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                dp[i][j] = min(
                    dp[i-1][j] + 1,
                    dp[i][j-1] + 1,
                    dp[i-1][j-1] + cost
                )
            }
        }
        let dist = dp[m][n]
        let denom = max(m, n)
        return Double(dist) / Double(denom)
    }
}

// MARK: - Response Models
internal struct OpenAIChatResponse: Codable {
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let role: String; let content: String }
    let choices: [Choice]
}
