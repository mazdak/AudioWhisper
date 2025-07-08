import Foundation
import WhisperKit

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var downloadProgress: [WhisperModel: Double] = [:]
    @Published var downloadingModels: Set<WhisperModel> = []
    
    private let fileManager = FileManager.default
    
    nonisolated func isModelDownloaded(_ model: WhisperModel) async -> Bool {
        // Since WhisperKit manages models automatically, we'll assume models
        // are available if WhisperKit can be initialized with that model
        do {
            let config = WhisperKitConfig(model: model.whisperKitModelName)
            _ = try await WhisperKit(config)
            return true
        } catch {
            return false
        }
    }
    
    nonisolated func downloadModel(_ model: WhisperModel) async throws {
        // Check if already downloading and mark as downloading
        let alreadyDownloading = await MainActor.run {
            if ModelManager.shared.downloadingModels.contains(model) {
                return true
            }
            ModelManager.shared.downloadingModels.insert(model)
            ModelManager.shared.downloadProgress[model] = 0.0
            return false
        }
        
        if alreadyDownloading {
            throw ModelError.alreadyDownloading
        }
        
        do {
            let config = WhisperKitConfig(model: model.whisperKitModelName)
            _ = try await WhisperKit(config)
            
            // WhisperKit handles model downloading automatically
            // Update progress to completion since we can't track intermediate progress
            await MainActor.run {
                ModelManager.shared.downloadProgress[model] = 1.0
            }
            
            // Clean up download state on success
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadProgress.removeValue(forKey: model)
            }
        } catch {
            // Clean up download state on error
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadProgress.removeValue(forKey: model)
            }
            throw error
        }
    }
    
    @MainActor
    private func updateDownloadProgress(_ model: WhisperModel, progress: Double) {
        downloadProgress[model] = progress
    }
    
    nonisolated func deleteModel(_ model: WhisperModel) async throws {
        // WhisperKit manages model storage internally and doesn't currently support deletion
        // We could potentially clear the local cache in LocalWhisperService
        // For now, provide clear feedback to the user
        throw ModelError.deletionNotSupported
    }
    
    // Alternative: Check if model can be deleted
    nonisolated func canDeleteModel(_ model: WhisperModel) -> Bool {
        // WhisperKit doesn't currently support model deletion
        return false
    }
    
    nonisolated func getDownloadedModels() async -> [WhisperModel] {
        // Check which models can be successfully initialized
        var downloadedModels: [WhisperModel] = []
        
        for model in WhisperModel.allCases {
            if await isModelDownloaded(model) {
                downloadedModels.append(model)
            }
        }
        
        return downloadedModels
    }
    
    nonisolated func getTotalModelsSize() async -> Int64 {
        // WhisperKit manages model storage internally
        // We can't easily determine the size without access to the internal storage
        // Return 0 for now, or implement estimation based on model types
        let downloadedModels = await getDownloadedModels()
        return downloadedModels.reduce(0) { total, model in
            total + model.estimatedSize
        }
    }
}

enum ModelError: LocalizedError {
    case alreadyDownloading
    case downloadFailed
    case modelNotFound
    case applicationSupportDirectoryNotFound
    case deletionNotSupported
    
    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return "Model is already being downloaded"
        case .downloadFailed:
            return "Failed to download model"
        case .modelNotFound:
            return "Model file not found"
        case .applicationSupportDirectoryNotFound:
            return "Application Support directory not found"
        case .deletionNotSupported:
            return "Model deletion not supported by WhisperKit"
        }
    }
}

extension WhisperModel {
    var estimatedSize: Int64 {
        switch self {
        case .tiny:
            return 39 * 1024 * 1024 // 39MB
        case .base:
            return 142 * 1024 * 1024 // 142MB
        case .small:
            return 466 * 1024 * 1024 // 466MB
        case .medium:
            return 1536 * 1024 * 1024 // 1.5GB
        case .large:
            return 2944 * 1024 * 1024 // 2.9GB
        case .largeTurbo:
            return 1536 * 1024 * 1024 // 1.5GB
        }
    }
}