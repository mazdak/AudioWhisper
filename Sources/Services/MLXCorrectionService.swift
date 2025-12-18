import Foundation
import os.log

internal enum MLXCorrectionError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case scriptNotFound
    case correctionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    case daemonUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python executable not found at: \(path)\n\nFix:\n• Open Settings ▸ Local LLM ▸ Install/Update Dependencies with uv"
        case .scriptNotFound:
            return "MLX correction script not found in app bundle"
        case .correctionFailed(let message):
            return "MLX correction failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from MLX correction: \(message)"
        case .dependencyMissing(let dependency, let installCommand):
            return "\(dependency) is not installed\n\nFix: Run: \(installCommand)\nOr open Settings ▸ Local LLM ▸ Install/Update Dependencies with uv"
        case .processTimedOut(let timeout):
            return "Correction timed out after \(timeout) seconds\n\nTry shorter text or check system resources"
        case .daemonUnavailable(let reason):
            return "ML daemon unavailable: \(reason)\n\nTry restarting the app"
        }
    }
}

internal struct MLXCorrectionResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

internal protocol MLDaemonManaging {
    func correct(repo: String, text: String, prompt: String?) async throws -> String
    func ping() async -> Bool
}

extension MLDaemonManager: MLDaemonManaging {}

internal final class MLXCorrectionService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "MLXCorrectionService")
    private let daemon: MLDaemonManaging
    private let promptLoader: () -> String?

    init(daemon: MLDaemonManaging = MLDaemonManager.shared,
         promptLoader: @escaping () -> String? = MLXCorrectionService.loadSystemPrompt) {
        self.daemon = daemon
        self.promptLoader = promptLoader
    }

    func correct(text: String, modelRepo: String, pythonPath: String, systemPrompt: String? = nil) async throws -> String {
        // pythonPath is kept for API compatibility but daemon manages its own Python
        
        // Use provided prompt, or fall back to user's custom file, or nil for daemon default
        let prompt = systemPrompt ?? promptLoader()
        
        do {
            let result = try await daemon.correct(repo: modelRepo, text: text, prompt: prompt)
            return result
        } catch let error as MLDaemonError {
            // Map daemon errors to MLXCorrectionError for compatibility
            switch error {
            case .scriptNotFound:
                throw MLXCorrectionError.scriptNotFound
            case .daemonUnavailable(let reason):
                throw MLXCorrectionError.daemonUnavailable(reason)
            case .invalidResponse(let reason):
                throw MLXCorrectionError.invalidResponse(reason)
            case .remoteError(let message):
                if message.contains("mlx_lm") || message.contains("ModuleNotFoundError") {
                    throw MLXCorrectionError.dependencyMissing("mlx-lm", installCommand: "uv add mlx-lm")
                }
                throw MLXCorrectionError.correctionFailed(message)
            case .restartLimitReached:
                throw MLXCorrectionError.daemonUnavailable("restart limit reached")
            case .writeFailed:
                throw MLXCorrectionError.daemonUnavailable("failed to communicate with daemon")
            }
        } catch {
            logger.error("MLX correction error: \(error.localizedDescription)")
            throw MLXCorrectionError.correctionFailed(error.localizedDescription)
        }
    }

    // Cache invalidation is a no-op since daemon handles model loading
    func invalidateCache(for pythonPath: String? = nil) {
        // No-op: daemon manages model caching internally
    }
    
    func validateSetup(pythonPath: String) async throws {
        // Validate Python path exists (for settings UI feedback)
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw MLXCorrectionError.pythonNotFound(path: pythonPath)
        }
        
        // Use daemon ping to verify the daemon is healthy
        let isHealthy = await daemon.ping()
        if !isHealthy {
            throw MLXCorrectionError.daemonUnavailable("daemon not responding")
        }
    }
    
    // MARK: - Private Helpers
    
    private static func loadSystemPrompt() -> String? {
        guard let promptsDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("AudioWhisper/prompts", isDirectory: true) else {
            return nil
        }
        
        let promptPath = promptsDir.appendingPathComponent("local_mlx_prompt.txt")
        guard FileManager.default.fileExists(atPath: promptPath.path) else {
            return nil
        }
        
        return try? String(contentsOf: promptPath, encoding: .utf8)
    }
}
