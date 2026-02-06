import Foundation

import os.log

internal final class SemanticCorrectionService {
    private let mlxService = MLXCorrectionService()
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
        // keychainService parameter kept for API compatibility but no longer used
    }

    func correct(text: String, providerUsed: TranscriptionProvider, sourceAppBundleId: String? = nil) async -> String {
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        let category = categoryFor(bundleId: sourceAppBundleId)
        logger.info("Correction category: \(category.id) for bundleId: \(sourceAppBundleId ?? "nil")")

        switch mode {
        case .off:
            return text
        case .localMLX:
            // Allow local MLX correction regardless of STT provider
            logger.info("Running local MLX correction")
            return await correctLocallyWithMLX(text: text, category: category)
        }
    }

    // MARK: - Local (MLX)
    private func correctLocallyWithMLX(text: String, category: CategoryDefinition) async -> String {
        guard Arch.isAppleSilicon else { return text }
        let modelRepo = UserDefaults.standard.string(forKey: "semanticCorrectionModelRepo") ?? "mlx-community/Llama-3.2-1B-Instruct-4bit"
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
            return merged
        } catch {
            logger.error("MLX correction failed: \(error.localizedDescription)")
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
            if let userPrompt = try? String(contentsOf: url, encoding: .utf8) {
                let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
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

    /// Computes normalized edit distance using space-efficient 2-row DP.
    /// Memory: O(min(m,n)) instead of O(m*n) for full matrix.
    static func normalizedEditDistance(a: String, b: String) -> Double {
        if a == b { return 0 }
        let aChars = Array(a)
        let bChars = Array(b)
        var m = aChars.count
        var n = bChars.count
        if m == 0 || n == 0 { return 1 }

        // Optimize: ensure we iterate over shorter string in inner loop
        let (shorter, longer): ([Character], [Character])
        if m > n {
            shorter = bChars
            longer = aChars
            swap(&m, &n)
        } else {
            shorter = aChars
            longer = bChars
        }

        // Two-row DP: only keep current and previous rows
        var previousRow = Array(0...shorter.count)
        var currentRow = Array(repeating: 0, count: shorter.count + 1)

        for i in 1...longer.count {
            currentRow[0] = i
            for j in 1...shorter.count {
                let cost = longer[i - 1] == shorter[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,      // deletion
                    currentRow[j - 1] + 1,   // insertion
                    previousRow[j - 1] + cost // substitution
                )
            }
            swap(&previousRow, &currentRow)
        }

        let dist = previousRow[shorter.count]
        let denom = max(aChars.count, bChars.count)
        return Double(dist) / Double(denom)
    }
}
