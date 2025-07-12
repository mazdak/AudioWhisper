import Foundation
import os.log

enum ParakeetError: Error, LocalizedError, Equatable {
    case pythonNotFound
    case scriptNotFound
    case transcriptionFailed(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python executable not found at the specified path"
        case .scriptNotFound:
            return "Parakeet transcription script not found"
        case .transcriptionFailed(let message):
            return "Parakeet transcription failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Parakeet: \(message)"
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
    
    func transcribe(audioFileURL: URL, pythonPath: String) async throws -> String {
        logger.info("Starting Parakeet transcription...")
        logger.info("Audio file: \(audioFileURL.path)")
        logger.info("Python path: \(pythonPath)")
        
        // Validate Python path
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            logger.error("Python not found at: \(pythonPath)")
            throw ParakeetError.pythonNotFound
        }
        
        // Get the Parakeet script path from bundle
        guard let scriptURL = Bundle.main.url(forResource: "parakeet_transcribe", withExtension: "py") ??
              Bundle.module.url(forResource: "parakeet_transcribe", withExtension: "py") else {
            logger.error("Failed to find parakeet_transcribe.py in bundle")
            throw ParakeetError.scriptNotFound
        }
        
        logger.info("Found script at: \(scriptURL.path)")
        
        // Create a temporary copy of the script with the correct shebang
        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet_transcribe_\(UUID().uuidString).py")
        
        do {
            // Read the original script
            var scriptContent = try String(contentsOf: scriptURL, encoding: .utf8)
            
            // Replace the shebang with the user's Python path
            if scriptContent.hasPrefix("#!") {
                let lines = scriptContent.components(separatedBy: .newlines)
                if !lines.isEmpty {
                    var modifiedLines = lines
                    modifiedLines[0] = "#!\(pythonPath)"
                    scriptContent = modifiedLines.joined(separator: "\n")
                }
            }
            
            // Write the modified script
            try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            
            // Make the script executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            
            // Ensure we clean up the temp script
            defer {
                try? FileManager.default.removeItem(at: tempScriptURL)
            }
            
            // Run the Python script
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [tempScriptURL.path, audioFileURL.path]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            logger.info("Running Parakeet transcription for file: \(audioFileURL.path)")
            
            try process.run()
            
            // Wait for process to complete
            process.waitUntilExit()
            
            // Read output after process completes
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            
            // Log stderr output for debugging
            if !errorString.isEmpty {
                logger.info("Parakeet stderr: \(errorString)")
            }
            
            if process.terminationStatus != 0 {
                logger.error("Parakeet process failed with status: \(process.terminationStatus)")
                logger.error("Error output: \(errorString)")
                throw ParakeetError.transcriptionFailed(errorString.isEmpty ? "Process exited with status \(process.terminationStatus)" : errorString)
            }
            
            // Parse the JSON response
            guard let responseData = outputString.data(using: .utf8) else {
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
            throw ParakeetError.pythonNotFound
        }
        
        // Check if parakeet_mlx is installed
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", "import parakeet_mlx; print('OK')"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw ParakeetError.transcriptionFailed("parakeet-mlx not installed: \(output)")
        }
    }
}