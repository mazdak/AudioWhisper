import Foundation
import os.log

/// Utility to detect Python installations with specific packages
internal struct PythonDetector {
    static let logger = Logger(subsystem: "com.audiowhisper.app", category: "PythonDetector")
    
    /// Find Python executable with mlx-lm installed
    static func findPythonWithMLX() async -> String? {
        let candidates = [
            // uv virtual environment in current directory
            ".venv/bin/python",
            ".venv/bin/python3",
            
            // Common uv installation paths
            FileManager.default.homeDirectoryForCurrentUser.path + "/.venv/bin/python",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.venv/bin/python3",
            
            // pyenv paths
            FileManager.default.homeDirectoryForCurrentUser.path + "/.pyenv/shims/python",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.pyenv/shims/python3",
            
            // Homebrew Python
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            
            // System Python (usually doesn't have mlx-lm)
            "/usr/bin/python3"
        ]
        
        for candidate in candidates {
            if await checkPythonHasMLX(at: candidate) {
                logger.info("Found Python with mlx-lm at: \(candidate)")
                return candidate
            }
        }
        
        // Try to find it via which command
        if let whichPath = await findViaWhich() {
            if await checkPythonHasMLX(at: whichPath) {
                return whichPath
            }
        }
        
        return nil
    }
    
    /// Check if a Python executable has mlx-lm installed
    static func checkPythonHasMLX(at path: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["-c", "import mlx_lm; print('OK')"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8),
                   output.contains("OK") {
                    return true
                }
            }
        } catch {
            logger.debug("Failed to check Python at \(path): \(error)")
        }
        
        return false
    }
    
    /// Try to find Python via which command
    static func findViaWhich() async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty {
                        return path
                    }
                }
            }
        } catch {
            logger.debug("Failed to run which: \(error)")
        }
        
        return nil
    }
}