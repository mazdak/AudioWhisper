import Foundation
import WhisperKit
import UserNotifications
import os.log

@MainActor
class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var downloadProgress: [WhisperModel: Double] = [:]
    @Published var downloadingModels: Set<WhisperModel> = []
    @Published var downloadStages: [WhisperModel: DownloadStage] = [:]
    @Published var downloadedModels: Set<WhisperModel> = []
    @Published var downloadEstimates: [WhisperModel: TimeInterval] = [:]
    @Published var lastRefresh: Date = Date()
    
    // FileManager operations are performed directly to avoid Sendable warnings
    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?
    private var isDeleteInProgress: Set<WhisperModel> = []
    
    init() {
        // Disable automatic file system watching to prevent unwanted re-downloads
        // setupFileSystemWatching() 
        
        // Only refresh manually when user requests it
        // startPeriodicRefresh()
        
        Task {
            await refreshDownloadedModels()
        }
    }
    
    deinit {
        fileSystemWatcher?.cancel()
        refreshTimer?.invalidate()
    }
    
    nonisolated func isModelDownloaded(_ model: WhisperModel) async -> Bool {
        // Only check if model files exist on disk - DO NOT initialize WhisperKit
        // as that triggers automatic downloads which users don't want
        return await isModelFileDownloaded(model)
    }
    
    // Check if model files exist in the known WhisperKit storage location
    nonisolated func isModelFileDownloaded(_ model: WhisperModel) async -> Bool {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let modelPath = documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.whisperKitModelName)
        
        // Check if the model directory exists and contains model files
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)
        
        if exists && isDirectory.boolValue {
            // Check for typical model files (config.json, pytorch_model.bin, etc.)
            let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
            let hasModelFiles = contents?.contains { $0.hasSuffix(".json") || $0.hasSuffix(".bin") || $0.hasSuffix(".mlmodelc") } ?? false
            return hasModelFiles
        }
        
        return false
    }
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ModelError.downloadTimeout
            }
            
            guard let result = try await group.next() else {
                throw ModelError.downloadTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    nonisolated func downloadModel(_ model: WhisperModel) async throws {
        // Check if already downloading and mark as downloading
        let alreadyDownloading = await MainActor.run {
            if ModelManager.shared.downloadingModels.contains(model) {
                return true
            }
            ModelManager.shared.downloadingModels.insert(model)
            ModelManager.shared.downloadStages[model] = .preparing
            return false
        }
        
        if alreadyDownloading {
            throw ModelError.alreadyDownloading
        }
        
        // Check storage limits
        let requiredSpace = model.estimatedSize
        let currentModelsSize = await getTotalModelsSize()
        let maxStorageGB = UserDefaults.standard.object(forKey: "maxModelStorageGB") as? Double ?? 5.0
        let maxStorageBytes = Int64(maxStorageGB * 1024 * 1024 * 1024)
        
        if currentModelsSize + requiredSpace > maxStorageBytes {
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadStages.removeValue(forKey: model)
            }
            throw ModelError.storageLimitExceeded
        }
        
        // Check available disk space
        let availableSpace = try await getAvailableStorageSpace()
        if availableSpace < requiredSpace + (100 * 1024 * 1024) { // Add 100MB buffer
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadStages.removeValue(forKey: model)
            }
            throw ModelError.insufficientStorage
        }
        
        do {
            // Update stage to downloading
            await MainActor.run {
                ModelManager.shared.downloadStages[model] = .downloading
                ModelManager.shared.downloadEstimates[model] = estimateDownloadTime(for: model)
            }
            
            let config = WhisperKitConfig(model: model.whisperKitModelName)
            
            // Update stage to processing
            await MainActor.run {
                ModelManager.shared.downloadStages[model] = .processing
            }
            
            _ = try await WhisperKit(config)
            
            // Update stage to completing
            await MainActor.run {
                ModelManager.shared.downloadStages[model] = .completing
            }
            
            // Brief delay to show completion stage
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Clean up download state on success
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadProgress.removeValue(forKey: model)
                ModelManager.shared.downloadStages[model] = .ready
                ModelManager.shared.downloadEstimates.removeValue(forKey: model)
                ModelManager.shared.downloadedModels.insert(model)
            }
            
            // Clear the ready stage after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                ModelManager.shared.downloadStages.removeValue(forKey: model)
            }
            
            // Send system notification
            await sendDownloadCompletionNotification(for: model)
            
        } catch {
            // Clean up download state on error
            await MainActor.run {
                ModelManager.shared.downloadingModels.remove(model)
                ModelManager.shared.downloadProgress.removeValue(forKey: model)
                ModelManager.shared.downloadStages[model] = .failed(error.localizedDescription)
                ModelManager.shared.downloadEstimates.removeValue(forKey: model)
            }
            
            // Clear the error stage after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                ModelManager.shared.downloadStages.removeValue(forKey: model)
            }
            
            throw error
        }
    }
    
    @MainActor
    private func updateDownloadProgress(_ model: WhisperModel, progress: Double) {
        downloadProgress[model] = progress
    }
    
    nonisolated func deleteModel(_ model: WhisperModel) async throws {
        // Find the model directory and delete it
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ModelError.applicationSupportDirectoryNotFound
        }
        
        let modelPath = documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.whisperKitModelName)
        
        // Mark as delete in progress to prevent re-download
        _ = await MainActor.run {
            isDeleteInProgress.insert(model)
        }
        
        // Check if the model directory exists
        if FileManager.default.fileExists(atPath: modelPath.path) {
            do {
                try FileManager.default.removeItem(at: modelPath)
                
                // Clear the model from LocalWhisperService cache
                await LocalWhisperService.shared.clearCache()
                
                // Update our tracking immediately
                await MainActor.run {
                    downloadedModels.remove(model)
                    isDeleteInProgress.remove(model)
                }
                
            } catch {
                _ = await MainActor.run {
                    isDeleteInProgress.remove(model)
                }
                throw ModelError.deletionFailed
            }
        } else {
            // Update our tracking since it's not actually there
            await MainActor.run {
                downloadedModels.remove(model)
                isDeleteInProgress.remove(model)
            }
        }
    }
    
    // Check if model can be deleted
    nonisolated func canDeleteModel(_ model: WhisperModel) -> Bool {
        // Models can be deleted by removing their directories
        return true
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
    
    // MARK: - Enhanced Model Management Methods
    
    private func setupFileSystemWatching() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let whisperKitPath = documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: whisperKitPath, withIntermediateDirectories: true)
        
        let descriptor = open(whisperKitPath.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        
        fileSystemWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        fileSystemWatcher?.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.refreshDownloadedModels()
            }
        }
        
        fileSystemWatcher?.setCancelHandler {
            close(descriptor)
        }
        
        fileSystemWatcher?.resume()
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshDownloadedModels()
            }
        }
    }
    
    @MainActor
    private func refreshDownloadedModels() async {
        var newDownloadedModels: Set<WhisperModel> = []
        
        for model in WhisperModel.allCases {
            if await isModelDownloaded(model) {
                newDownloadedModels.insert(model)
            }
        }
        
        // Only update if there are changes to avoid unnecessary UI updates
        if newDownloadedModels != downloadedModels {
            downloadedModels = newDownloadedModels
            lastRefresh = Date()
        }
    }
    
    private nonisolated func estimateDownloadTime(for model: WhisperModel) -> TimeInterval {
        // Estimate based on model size and typical download speeds
        let sizeInMB = Double(model.estimatedSize) / (1024 * 1024)
        
        // Assume average download speed of 10 MB/s (conservative estimate)
        let estimatedSeconds = sizeInMB / 10.0
        
        // Add processing time based on model size
        let processingTime = sizeInMB / 50.0 // Rough estimate for model processing
        
        return estimatedSeconds + processingTime
    }
    
    private nonisolated func getAvailableStorageSpace() async throws -> Int64 {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ModelError.applicationSupportDirectoryNotFound
        }
        
        let resourceValues = try documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(resourceValues.volumeAvailableCapacity ?? 0)
    }
    
    private nonisolated func sendDownloadCompletionNotification(for model: WhisperModel) async {
        let content = UNMutableNotificationContent()
        content.title = "Model Download Complete"
        content.body = "\(model.displayName) is ready for offline transcription"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "model-download-\(model.rawValue)",
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    @MainActor
    func refreshModelStates() async {
        await refreshDownloadedModels()
    }
    
    nonisolated func isModelReady(_ model: WhisperModel) -> Bool {
        return MainActor.assumeIsolated {
            downloadedModels.contains(model) && !downloadingModels.contains(model)
        }
    }
    
    @MainActor
    func getDownloadStage(for model: WhisperModel) -> DownloadStage? {
        return downloadStages[model]
    }
    
    @MainActor
    func getEstimatedTimeRemaining(for model: WhisperModel) -> TimeInterval? {
        return downloadEstimates[model]
    }
}

enum DownloadStage: Equatable {
    case preparing
    case downloading
    case processing
    case completing
    case ready
    case failed(String)
    
    var displayText: String {
        switch self {
        case .preparing: return "Preparing download..."
        case .downloading: return "Downloading model..."
        case .processing: return "Processing model files..."
        case .completing: return "Finalizing installation..."
        case .ready: return "Ready to use"
        case .failed(let error): return "Failed: \(error)"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .preparing, .downloading, .processing, .completing: return true
        case .ready, .failed: return false
        }
    }
}

enum ModelError: LocalizedError {
    case alreadyDownloading
    case downloadFailed
    case modelNotFound
    case applicationSupportDirectoryNotFound
    case deletionNotSupported
    case deletionFailed
    case downloadTimeout
    case insufficientStorage
    case storageLimitExceeded
    
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
        case .deletionFailed:
            return "Failed to delete model files"
        case .downloadTimeout:
            return "Model check timed out"
        case .insufficientStorage:
            return "Insufficient storage space for download"
        case .storageLimitExceeded:
            return "Model storage limit exceeded. Increase limit in settings or delete existing models."
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
        case .largeTurbo:
            return 1536 * 1024 * 1024 // 1.5GB
        }
    }
}