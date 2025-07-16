import Foundation
import os.log

enum MLXCorrectionError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case scriptNotFound
    case correctionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python runtime not available at: \(path)\n\nFix:\n• Open Settings ▸ Local LLM ▸ Install/Update Dependencies with uv"
        case .scriptNotFound:
            return "MLX correction script not found in app bundle"
        case .correctionFailed(let message):
            return "MLX correction failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from MLX correction: \(message)"
        case .dependencyMissing(let dependency, _):
            return "\(dependency) is not installed\n\nFix: Open Settings ▸ Local LLM ▸ Install/Update Dependencies with uv"
        case .processTimedOut(let timeout):
            return "Correction timed out after \(timeout) seconds\n\nTry shorter text or check system resources"
        }
    }
}

struct MLXCorrectionResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

final class MLXCorrectionService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "MLXCorrectionService")
    
    // Cache for mlx-lm availability - no expiration for menu bar app
    // Cache is only invalidated when:
    // 1. User changes Python path in settings
    // 2. User clicks "Test Setup" 
    // 3. App restarts
    private var mlxAvailabilityCache: [String: Bool] = [:]

    func correct(text: String, modelRepo: String, pythonPath: String) async throws -> String {
        // Validate Python path
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw MLXCorrectionError.pythonNotFound(path: pythonPath)
        }

        // Check cache first for mlx_lm availability
        if let isAvailable = mlxAvailabilityCache[pythonPath] {
            if !isAvailable {
                throw MLXCorrectionError.dependencyMissing("mlx-lm", installCommand: "pip install mlx-lm")
            }
            // If cached and available, continue without re-testing
        } else {
            // First time checking this pythonPath - test for mlx_lm availability
            let testProcess = Process()
            testProcess.executableURL = URL(fileURLWithPath: pythonPath)
            testProcess.arguments = ["-c", "import sys; import mlx_lm; print('OK')"]
            let testPipe = Pipe()
            testProcess.standardOutput = testPipe
            testProcess.standardError = testPipe

            do {
                try testProcess.run()
                testProcess.waitUntilExit()
                let isAvailable = testProcess.terminationStatus == 0
                
                // Cache the result indefinitely
                mlxAvailabilityCache[pythonPath] = isAvailable
                
                if !isAvailable {
                    throw MLXCorrectionError.dependencyMissing("mlx-lm", installCommand: "pip install mlx-lm")
                }
            } catch {
                // Cache the failure
                mlxAvailabilityCache[pythonPath] = false
                throw MLXCorrectionError.pythonNotFound(path: pythonPath)
            }
        }

        // Find script path (bundle first, then Sources for dev)
        var scriptURL: URL?
        scriptURL = Bundle.main.url(forResource: "mlx_semantic_correct", withExtension: "py")
        if scriptURL == nil {
            let currentDir = FileManager.default.currentDirectoryPath
            let sourceScriptPath = "\(currentDir)/Sources/mlx_semantic_correct.py"
            if FileManager.default.fileExists(atPath: sourceScriptPath) {
                scriptURL = URL(fileURLWithPath: sourceScriptPath)
            }
        }
        guard let scriptURL = scriptURL else { throw MLXCorrectionError.scriptNotFound }

        // Write input text to a temp file to avoid CLI length limits
        let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent("mlx_input_\(UUID().uuidString).txt")
        try text.data(using: .utf8)?.write(to: inputURL)
        defer { try? FileManager.default.removeItem(at: inputURL) }

        // Create a temporary copy of the script with the correct shebang
        let tempScriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("mlx_semantic_correct_\(UUID().uuidString).py")

        do {
            var scriptContent = try String(contentsOf: scriptURL, encoding: .utf8)
            if scriptContent.hasPrefix("#!") {
                let lines = scriptContent.components(separatedBy: .newlines)
                if !lines.isEmpty {
                    var modifiedLines = lines
                    modifiedLines[0] = "#!\(pythonPath)"
                    scriptContent = modifiedLines.joined(separator: "\n")
                }
            }
            try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            defer { try? FileManager.default.removeItem(at: tempScriptURL) }

            let (outputString, errorString, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String, Int32), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                // Optional: pass prompt file path for advanced customization
                let promptsDir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appendingPathComponent("AudioWhisper/prompts", isDirectory: true)
                let promptPath = promptsDir?.appendingPathComponent("local_mlx_prompt.txt").path
                var args = [tempScriptURL.path, modelRepo, inputURL.path]
                if let p = promptPath { args.append(p) }
                process.arguments = args

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                let timeout: UInt64 = 20_000_000_000 // 20s
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: timeout)
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: MLXCorrectionError.processTimedOut(Double(timeout) / 1_000_000_000))
                    }
                }

                process.terminationHandler = { p in
                    timeoutTask.cancel()
                    let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let outStr = String(data: outData, encoding: .utf8) ?? ""
                    let errStr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (outStr, errStr, p.terminationStatus))
                }

                do { try process.run() } catch { timeoutTask.cancel(); continuation.resume(throwing: error) }
            }

            if terminationStatus != 0 {
                logger.error("MLX process failed: \(terminationStatus); error=\(errorString)")
                if errorString.contains("mlx_lm") || errorString.contains("ModuleNotFoundError") {
                    throw MLXCorrectionError.dependencyMissing("mlx-lm", installCommand: "uv add mlx-lm")
                }
                throw MLXCorrectionError.correctionFailed(errorString.isEmpty ? "Process exited with status \(terminationStatus)" : errorString)
            }

            guard let responseData = outputString.data(using: .utf8) else {
                throw MLXCorrectionError.invalidResponse("Empty output")
            }
            let response = try JSONDecoder().decode(MLXCorrectionResponse.self, from: responseData)
            if response.success { return response.text }
            throw MLXCorrectionError.correctionFailed(response.error ?? "Unknown error")

        } catch {
            logger.error("MLX correction error: \(error.localizedDescription)")
            throw error
        }
    }

    // Public method to invalidate cache 
    // Called when:
    // - User clicks "Test Setup" button
    // - User changes Python path
    // - After installing/uninstalling mlx-lm
    func invalidateCache(for pythonPath: String? = nil) {
        if let path = pythonPath {
            mlxAvailabilityCache.removeValue(forKey: path)
        } else {
            mlxAvailabilityCache.removeAll()
        }
    }
    
    func validateSetup(pythonPath: String) async throws {
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw MLXCorrectionError.pythonNotFound(path: pythonPath)
        }
        
        // Invalidate cache for this path to force fresh check
        invalidateCache(for: pythonPath)
        
        let (_, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, Int32), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-c", "import mlx_lm; print('OK')"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                if process.isRunning { process.terminate(); continuation.resume(throwing: MLXCorrectionError.processTimedOut(5)) }
            }
            process.terminationHandler = { p in
                timeoutTask.cancel()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let _ = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: ("", p.terminationStatus))
            }
            do { try process.run() } catch { timeoutTask.cancel(); continuation.resume(throwing: error) }
        }
        if terminationStatus != 0 {
            throw MLXCorrectionError.dependencyMissing("mlx-lm", installCommand: "uv add mlx-lm")
        }
    }
}
