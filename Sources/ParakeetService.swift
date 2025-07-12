import Foundation
import os.log

enum ParakeetError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case ffmpegNotFound(suggestedPaths: [String])
    case scriptNotFound
    case transcriptionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python executable not found at: \(path)\n\nTry:\n• Use system Python: /usr/bin/python3\n• Install via Homebrew: brew install python3\n• Check if path exists and is executable"
        case .ffmpegNotFound(let suggestedPaths):
            let suggestions = suggestedPaths.joined(separator: "\n• ")
            return "FFmpeg not found in PATH\n\nInstall FFmpeg:\n• brew install ffmpeg\n\nOr specify custom path in settings:\n• \(suggestions)"
        case .scriptNotFound:
            return "Parakeet transcription script not found in app bundle"
        case .transcriptionFailed(let message):
            return "Parakeet transcription failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Parakeet: \(message)"
        case .dependencyMissing(let dependency, let installCommand):
            return "\(dependency) is not installed\n\nInstall with: \(installCommand)"
        case .processTimedOut(let timeout):
            return "Transcription timed out after \(timeout) seconds\n\nTry with a shorter audio file or check system resources"
        }
    }
}

struct ParakeetResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

class ParakeetService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ParakeetService")
    
    func transcribe(audioFileURL: URL, pythonPath: String, ffmpegPath: String = "") async throws -> String {
        logger.info("Starting Parakeet transcription...")
        logger.info("Audio file: \(audioFileURL.path)")
        logger.info("Python path: \(pythonPath)")
        
        // Validate Python path
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            logger.error("Python not found at: \(pythonPath)")
            throw ParakeetError.pythonNotFound(path: pythonPath)
        }
        
        // Get the Parakeet script path from bundle
        guard let scriptURL = Bundle.main.url(forResource: "parakeet_transcribe", withExtension: "py") else {
            logger.error("Failed to find parakeet_transcribe.py in bundle")
            throw ParakeetError.scriptNotFound
        }
        
        logger.info("Found script at: \(scriptURL.path)")
        
        // Create a temporary copy of the script with the correct shebang
        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet_transcribe_\(UUID().uuidString).py")
        
        do {
            // Read the original script asynchronously
            let scriptContent = try await Task {
                var content = try String(contentsOf: scriptURL, encoding: .utf8)
                
                // Replace the shebang with the user's Python path
                if content.hasPrefix("#!") {
                    let lines = content.components(separatedBy: .newlines)
                    if !lines.isEmpty {
                        var modifiedLines = lines
                        modifiedLines[0] = "#!\(pythonPath)"
                        content = modifiedLines.joined(separator: "\n")
                    }
                }
                return content
            }.value
            
            // Write the modified script asynchronously
            try await Task {
                try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            }.value
            
            // Ensure we clean up the temp script
            defer {
                try? FileManager.default.removeItem(at: tempScriptURL)
            }
            
            // Run the Python script asynchronously
            let (outputString, errorString, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String, Int32), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                
                // Pass FFmpeg path as environment variable if provided
                if !ffmpegPath.isEmpty {
                    var environment = ProcessInfo.processInfo.environment
                    environment["PARAKEET_FFMPEG_PATH"] = ffmpegPath
                    process.environment = environment
                }
                
                process.arguments = [tempScriptURL.path, audioFileURL.path]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Set up timeout handling (30 seconds for transcription)
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: ParakeetError.processTimedOut(30))
                    }
                }
                
                // Set up process completion handler
                process.terminationHandler = { process in
                    timeoutTask.cancel()
                    
                    // Read output after process completes
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outputString = String(data: outputData, encoding: .utf8) ?? ""
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: (outputString, errorString, process.terminationStatus))
                }
                
                logger.info("Running Parakeet transcription for file: \(audioFileURL.path)")
                
                do {
                    try process.run()
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                }
            }
            
            // Log stderr output for debugging
            if !errorString.isEmpty {
                logger.info("Parakeet stderr: \(errorString)")
            }
            
            if terminationStatus != 0 {
                logger.error("Parakeet process failed with status: \(terminationStatus)")
                logger.error("Error output: \(errorString)")
                
                // Provide more specific error handling
                if errorString.contains("parakeet_mlx") || errorString.contains("ModuleNotFoundError") {
                    throw ParakeetError.dependencyMissing("parakeet-mlx", installCommand: "pip install parakeet-mlx")
                } else if errorString.contains("ffmpeg") || errorString.contains("FFmpeg") {
                    let suggestedPaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
                    throw ParakeetError.ffmpegNotFound(suggestedPaths: suggestedPaths)
                } else {
                    throw ParakeetError.transcriptionFailed(errorString.isEmpty ? "Process exited with status \(terminationStatus)" : errorString)
                }
            }
            
            // Parse the JSON response
            guard let responseData = outputString.data(using: String.Encoding.utf8) else {
                throw ParakeetError.invalidResponse("Empty output")
            }
            
            let response = try JSONDecoder().decode(ParakeetResponse.self, from: responseData)
            
            if response.success {
                logger.info("Parakeet transcription successful")
                return response.text
            } else {
                throw ParakeetError.transcriptionFailed(response.error ?? "Unknown error")
            }
            
        } catch {
            logger.error("Parakeet transcription error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func validateSetup(pythonPath: String) async throws {
        // Check if Python exists
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw ParakeetError.pythonNotFound(path: pythonPath)
        }
        
        // Check if parakeet_mlx is installed using async process execution
        let (_, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, Int32), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-c", "import parakeet_mlx; print('OK')"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            // Set up timeout for validation (10 seconds)
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if process.isRunning {
                    process.terminate()
                    continuation.resume(throwing: ParakeetError.processTimedOut(10))
                }
            }
            
            process.terminationHandler = { process in
                timeoutTask.cancel()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (output, process.terminationStatus))
            }
            
            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: error)
            }
        }
        
        if terminationStatus != 0 {
            throw ParakeetError.dependencyMissing("parakeet-mlx", installCommand: "pip install parakeet-mlx")
        }
    }
}