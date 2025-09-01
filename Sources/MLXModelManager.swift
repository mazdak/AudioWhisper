import Foundation
import SwiftUI
import os.log

struct MLXModel: Identifiable, Equatable {
    let id = UUID()
    let repo: String
    let estimatedSize: String
    let description: String
    
    var displayName: String {
        repo.split(separator: "/").last.map(String.init) ?? repo
    }
}

@MainActor
final class MLXModelManager: ObservableObject {
    static let shared = MLXModelManager()
    
    @Published var downloadedModels: Set<String> = []
    @Published var modelSizes: [String: Int64] = [:]
    @Published var isDownloading: [String: Bool] = [:]
    @Published var downloadProgress: [String: String] = [:]
    @Published var totalCacheSize: Int64 = 0
    
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "MLXModelManager")
    private let cacheDirectory: URL

    static let parakeetRepo = "mlx-community/parakeet-tdt-0.6b-v2"
    
    // Popular models for semantic correction (real model names from Hugging Face)
    static let recommendedModels = [
        MLXModel(
            repo: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            estimatedSize: "1.9 GB",
            description: "Meta's latest, excellent quality"
        ),
        MLXModel(
            repo: "mlx-community/Qwen3-4B-Instruct-2507-5bit",
            estimatedSize: "2.8 GB",
            description: "High quality correction"
        ),
        // (Gemma-3n removed per current support decision)
    ]
    
    private init() {
        self.cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        Task {
            await refreshModelList()
        }
    }
    
    func refreshModelList() async {
        await MainActor.run {
            self.downloadedModels.removeAll()
            self.modelSizes.removeAll()
            self.totalCacheSize = 0
        }
        
        guard FileManager.default.fileExists(atPath: cacheDirectory.path) else {
            logger.info("Hugging Face cache directory doesn't exist")
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil
            )
            
            var totalSize: Int64 = 0
            
            for item in contents {
                guard item.lastPathComponent.hasPrefix("models--") else { continue }
                
                // Convert directory name back to repo format
                let modelName = item.lastPathComponent
                    .replacingOccurrences(of: "models--", with: "")
                    .replacingOccurrences(of: "--", with: "/")
                
                // Check if this looks like an MLX model
                let mlxKeywords = ["mlx", "qwen", "llama", "phi", "mistral", "gemma", "starcoder", "parakeet"]
                let isLikelyMLX = mlxKeywords.contains { modelName.lowercased().contains($0) }
                
                if isLikelyMLX {
                    let size = calculateDirectorySize(at: item)
                    await MainActor.run {
                        self.downloadedModels.insert(modelName)
                        self.modelSizes[modelName] = size
                        totalSize += size
                    }
                }
            }
            
            await MainActor.run {
                self.totalCacheSize = totalSize
            }
            
            logger.info("Found \(self.downloadedModels.count) MLX models, total size: \(self.formatBytes(totalSize))")
        } catch {
            logger.error("Failed to scan model directory: \(error.localizedDescription)")
        }
    }
    
    func downloadModel(_ repo: String) async {
        logger.info("Starting MLX model download for: \(repo)")
        // Ensure managed Python via uv
        let pythonPath: String
        do {
            let py = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                self.logger.info("uv: \(msg)")
            }
            pythonPath = py.path
        } catch {
            logger.error("Failed to prepare Python environment: \(error.localizedDescription)")
            await MainActor.run {
                downloadProgress[repo] = "Error: Could not prepare Python environment"
                isDownloading[repo] = false
            }
            return
        }
        logger.info("Using managed Python at: \(pythonPath)")
        
        await MainActor.run {
            isDownloading[repo] = true
            downloadProgress[repo] = "Checking Python environment..."
        }
        
        logger.info("Starting download for model: \(repo) with Python: \(pythonPath)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        let pythonScript = """
import sys
import json
import os
import traceback

# Set environment to show download progress and force offline operation
os.environ['HF_HUB_DISABLE_PROGRESS_BARS'] = '0'
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_IMPLICIT_TOKEN'] = '1'

try:
    print(json.dumps({"status": "checking", "message": "Checking mlx-lm..."}), flush=True)

    from mlx_lm import load

    print(json.dumps({"status": "downloading", "message": "Loading model (offline mode)..."}), flush=True)

    model, tokenizer = load("\(repo)", local_files_only=True)

    print(json.dumps({"status": "complete", "message": "Model loaded successfully"}), flush=True)

except ImportError as e:
    error_msg = f"mlx-lm not installed. Run: uv add mlx-lm. Error: {str(e)}"
    print(json.dumps({"status": "error", "message": error_msg}), flush=True)
    sys.exit(1)
except Exception as e:
    error_msg = f"Error: {str(e)}\\nTraceback: {traceback.format_exc()}"
    print(json.dumps({"status": "error", "message": error_msg}), flush=True)
    sys.exit(1)
"""
        process.arguments = ["-c", pythonScript]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let output = String(data: data, encoding: .utf8) {
                self.logger.info("Python stdout: \(output)")
                // Process each line separately as JSON might come in multiple lines
                let lines = output.split(separator: "\n")
                for line in lines {
                    let lineStr = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                    if lineStr.isEmpty { continue }
                    
                    Task { @MainActor in
                        // Try to parse as JSON
                        if let jsonData = lineStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let message = json["message"] as? String {
                            self.downloadProgress[repo] = message
                            self.logger.info("Download progress for \(repo): \(message)")
                        } else if lineStr.contains("Downloading") || lineStr.contains("%") || lineStr.contains("model.safetensors") {
                            // Capture raw download progress
                            if let percentRange = lineStr.range(of: #"\d+%"#, options: .regularExpression) {
                                let percent = String(lineStr[percentRange])
                                self.downloadProgress[repo] = "Downloading: \(percent)"
                            } else if lineStr.contains("MB/s") || lineStr.contains("GB/s") {
                                // Extract file being downloaded
                                let components = lineStr.split(separator: ":")
                                if let fileName = components.first {
                                    self.downloadProgress[repo] = "Downloading: \(fileName)..."
                                }
                            } else {
                                self.downloadProgress[repo] = "Downloading model files..."
                            }
                        } else if lineStr.contains(".json") || lineStr.contains(".safetensors") {
                            // Show which file is being downloaded
                            let components = lineStr.split(separator: ":")
                            if let fileName = components.first {
                                self.downloadProgress[repo] = "Fetching: \(fileName)"
                            }
                        }
                    }
                }
            }
        }
        
        // Collect all stderr for final error message
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let error = String(data: data, encoding: .utf8) {
                // Check if this is actually an error or just progress info
                let lowerError = error.lowercased()
                let isRealError = (lowerError.contains("error") || 
                                  lowerError.contains("exception") || 
                                  lowerError.contains("failed") ||
                                  lowerError.contains("traceback") ||
                                  lowerError.contains("no module") ||
                                  lowerError.contains("not found")) &&
                                 !lowerError.contains("process exited with status: 0") // Success message
                
                // Ignore common progress messages that go to stderr
                let isProgress = error.contains("Fetching") || 
                               error.contains("Downloading") || 
                               error.contains("%") ||
                               error.contains("it/s") ||
                               error.contains("MB/s") ||
                               error.contains("GB/s")
                
                if isRealError && !isProgress {
                    self.logger.error("Python stderr: \(error)")
                    Task { @MainActor in
                        // Show the actual error in the UI
                        let errorLines = error.split(separator: "\n").prefix(2).joined(separator: " ")
                        self.downloadProgress[repo] = "Error: \(errorLines)"
                    }
                } else if isProgress {
                    // It's just progress info, not an error
                    self.logger.info("Python progress (stderr): \(error)")
                }
            }
        }
        
        do {
            logger.info("Launching Python process...")
            try process.run()
            logger.info("Python process launched, waiting for completion...")
            
            // Wait for process in background
            Task.detached {
                process.waitUntilExit()
                
                let exitStatus = process.terminationStatus
                
                
                await MainActor.run { [weak self] in
                    self?.isDownloading[repo] = false
                    if exitStatus != 0 {
                        self?.downloadProgress[repo] = "Error: Download failed (exit code: \(exitStatus))"
                    } else {
                        self?.downloadProgress.removeValue(forKey: repo)
                    }
                    
                    if exitStatus == 0 {
                        Task {
                            await self?.refreshModelList()
                        }
                        self?.logger.info("Successfully downloaded model: \(repo)")
                    } else {
                        self?.logger.error("Failed to download model: \(repo) with exit code: \(exitStatus)")
                    }
                }
            }
        } catch {
            logger.error("Failed to launch Python process: \(error)")
            await MainActor.run {
                isDownloading[repo] = false
                downloadProgress[repo] = "Error: \(error.localizedDescription)"
            }
        }
    }

    func ensureParakeetModel() async {
        await refreshModelList()
        if downloadedModels.contains(Self.parakeetRepo) { return }
        await downloadParakeetModel()
    }

    func downloadParakeetModel() async {
        let repo = Self.parakeetRepo
        logger.info("Starting Parakeet model download for: \(repo)")

        let pythonPath: String
        do {
            let py = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                self.logger.info("uv: \(msg)")
            }
            pythonPath = py.path
        } catch {
            logger.error("Failed to prepare Python environment: \(error.localizedDescription)")
            await MainActor.run {
                downloadProgress[repo] = "Error: Could not prepare Python environment"
                isDownloading[repo] = false
            }
            return
        }

        await MainActor.run {
            isDownloading[repo] = true
            downloadProgress[repo] = "Downloading Parakeet model..."
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        let pythonScript = """
import json, sys, traceback, os

# Set environment to force offline operation
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_IMPLICIT_TOKEN'] = '1'

try:
    from parakeet_mlx import from_pretrained
    from_pretrained(\"\(repo)\", local_files_only=True)
    print(json.dumps({"status": "complete", "message": "Model loaded"}), flush=True)
except Exception as e:
    print(json.dumps({"status": "error", "message": str(e)}), flush=True)
    sys.exit(1)
"""
        process.arguments = ["-c", pythonScript]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let line = String(data: data, encoding: .utf8),
               let jsonData = line.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String],
               let message = json["message"],
               let status = json["status"] {
                Task { @MainActor in
                    self.downloadProgress[repo] = message
                    if status == "complete" {
                        self.downloadedModels.insert(repo)
                    }
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let err = String(data: data, encoding: .utf8) {
                self.logger.error("Parakeet download stderr: \(err)")
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            await MainActor.run {
                self.downloadProgress[repo] = "Error: \(error.localizedDescription)"
            }
        }

        await MainActor.run {
            self.isDownloading[repo] = false
        }
    }

    func deleteModel(_ repo: String) async {
        let escapedRepo = repo.replacingOccurrences(of: "/", with: "--")
        let modelPath = cacheDirectory.appendingPathComponent("models--\(escapedRepo)")
        
        do {
            try FileManager.default.removeItem(at: modelPath)
            await MainActor.run {
                downloadedModels.remove(repo)
                modelSizes.removeValue(forKey: repo)
            }
            await refreshModelList()
            logger.info("Deleted model: \(repo)")
        } catch {
            logger.error("Failed to delete model: \(error.localizedDescription)")
        }
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                size += Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
            } catch {
                continue
            }
        }
        
        return size
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
