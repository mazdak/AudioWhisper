import Foundation

import os.log

/// The result of attempting a semantic-correction pass.
///
/// Returned from `SemanticCorrectionService.correctWithOutcome(...)` so callers
/// can distinguish a successful correction from a no-op (user disabled it) or
/// a silent failure (e.g. MLX subprocess crashed). The legacy
/// `correct(...) -> String` API erases this distinction; new callers should
/// prefer the outcome-aware API. See audit item B2.
internal enum CorrectionOutcome {
    /// Correction was applied successfully; associated value is the corrected text.
    case applied(String)
    /// Correction was disabled by user settings; original text is returned unchanged.
    case skipped(String)
    /// Correction was attempted but failed; the original text is returned as a fallback.
    case failed(Error, fallback: String)

    /// Convenience: the text to use in the UI, regardless of outcome.
    var text: String {
        switch self {
        case .applied(let s), .skipped(let s): return s
        case .failed(_, fallback: let s): return s
        }
    }
}

/// Post-processes raw transcripts to fix typos, punctuation, and filler words.
/// Mode is read from preferences: off / local MLX / cloud (uses the active
/// transcription provider).
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

    /// Applies semantic correction to `text`. Reads `semanticCorrectionMode` from
    /// `UserDefaults` and picks: off (returns input unchanged) or local MLX. The
    /// per-app category is derived from `sourceAppBundleId` to choose the prompt.
    /// On failure, returns the original `text` silently — see audit item B2 and
    /// prefer `correctWithOutcome(...)` for new code.
    ///
    /// This method is preserved as a thin wrapper around `correctWithOutcome` so
    /// existing call sites keep their `async -> String` contract unchanged.
    func correct(text: String, providerUsed: TranscriptionProvider, sourceAppBundleId: String? = nil) async -> String {
        await correctWithOutcome(text: text, providerUsed: providerUsed, sourceAppBundleId: sourceAppBundleId).text
    }

    /// Outcome-aware semantic correction API.
    ///
    /// Preferred entry point for new callers (and for surfacing failures to the
    /// UI per audit item B2). Returns:
    /// - `.skipped(text)` if `semanticCorrectionMode == .off`
    /// - `.applied(corrected)` if correction ran and produced text (possibly
    ///   identical to the input after safe-merge)
    /// - `.failed(error, fallback: text)` if the correction pipeline threw;
    ///   the fallback is the unchanged original text so callers can still
    ///   show something useful.
    func correctWithOutcome(text: String, providerUsed: TranscriptionProvider, sourceAppBundleId: String? = nil) async -> CorrectionOutcome {
        let modeRaw = UserDefaults.standard.string(forKey: "semanticCorrectionMode") ?? SemanticCorrectionMode.off.rawValue
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off

        let category = categoryFor(bundleId: sourceAppBundleId)
        logger.info("Correction category: \(category.id) for bundleId: \(sourceAppBundleId ?? "nil")")

        switch mode {
        case .off:
            return .skipped(text)
        case .localMLX:
            // Allow local MLX correction regardless of STT provider
            logger.info("Running local MLX correction")
            do {
                let corrected = try await correctLocallyWithMLXThrowing(text: text, category: category)
                return .applied(corrected)
            } catch {
                logger.error("MLX correction failed: \(error.localizedDescription)")
                return .failed(error, fallback: text)
            }
        }
    }

    // MARK: - Local (MLX)
    /// Runs the local MLX correction model for `text` using the category-specific
    /// prompt. Requires Apple Silicon; on non-arm64 returns `text` unchanged.
    /// Any subprocess or model failure logs and returns the original text silently
    /// — this preserves the contract for the legacy `correct(...) -> String` API.
    /// For new callers that want to know about failures, use `correctWithOutcome`,
    /// which routes through `correctLocallyWithMLXThrowing` and surfaces errors
    /// as `.failed`.
    private func correctLocallyWithMLX(text: String, category: CategoryDefinition) async -> String {
        do {
            return try await correctLocallyWithMLXThrowing(text: text, category: category)
        } catch {
            logger.error("MLX correction failed: \(error.localizedDescription)")
            return text
        }
    }

    /// Throwing variant of `correctLocallyWithMLX`. Used by `correctWithOutcome`
    /// so callers can distinguish success from failure. On non-Apple-Silicon
    /// hosts this returns the input unchanged (treated as a successful no-op,
    /// not a failure — there's nothing to recover from).
    private func correctLocallyWithMLXThrowing(text: String, category: CategoryDefinition) async throws -> String {
        guard Arch.isAppleSilicon else { return text }
        let modelRepo = UserDefaults.standard.string(forKey: "semanticCorrectionModelRepo") ?? "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let pyURL = try await UvBootstrap.ensureVenv(userPython: nil)
        let prompt = loadPrompt(for: category)
        let output = try await mlxService.correct(text: text, modelRepo: modelRepo, pythonPath: pyURL.path, systemPrompt: prompt)
        let merged = Self.safeMerge(original: text, corrected: output, maxChangeRatio: 0.6)
        if merged == text {
            logger.info("MLX correction produced no accepted change (kept original)")
        } else {
            logger.info("MLX correction applied changes")
        }
        return merged
    }

    // MARK: - Prompt file helpers
    private func promptsBaseDir() -> URL? {
        return try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioWhisper/prompts", isDirectory: true)
    }

    private func loadPrompt(for category: CategoryDefinition) -> String {
        let defaultPrompt: String = {
            let trimmed = category.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
            return CategoryDefinition.fallback.promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        // Reject names that aren't a safe identifier — prevents path traversal
        // (e.g. "../../etc/passwd") if category names ever come from imported
        // config. Audit item E3.
        let name = category.id
        let sanitized = name.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        guard sanitized == name, !sanitized.isEmpty else {
            logger.warning("Rejected unsafe category id for prompt path: \(name, privacy: .public)")
            return defaultPrompt
        }

        guard let base = promptsBaseDir() else { return defaultPrompt }
        let promptsDir = base.standardizedFileURL
        let promptURL = promptsDir.appendingPathComponent("\(sanitized)_prompt.txt").standardizedFileURL

        // Defense in depth: even with sanitized name, verify the resolved path
        // is still under the prompts directory before reading.
        guard promptURL.path.hasPrefix(promptsDir.path + "/") || promptURL.path == promptsDir.path else {
            logger.warning("Prompt path escaped prompts dir: \(promptURL.path, privacy: .public)")
            return defaultPrompt
        }

        if let userPrompt = try? String(contentsOf: promptURL, encoding: .utf8) {
            let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return defaultPrompt
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
