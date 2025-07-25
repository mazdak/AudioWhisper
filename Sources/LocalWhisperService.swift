import Foundation
@preconcurrency import WhisperKit
import AVFoundation

// Actor to manage WhisperKit instances safely across concurrency boundaries
private actor WhisperKitCache {
    private var instances: [String: WhisperKit] = [:]
    private var accessTimes: [String: Date] = [:]
    
    func getOrCreate(modelName: String, model: WhisperModel, maxCached: Int, progressCallback: (@Sendable (String) -> Void)?) async throws -> WhisperKit {
        // Check if we have a cached instance
        if let existingInstance = instances[modelName] {
            // Update access time for LRU tracking
            accessTimes[modelName] = Date()
            return existingInstance
        }
        
        // Create new instance
        progressCallback?("Preparing \(model.displayName) model...")
        let config = WhisperKitConfig(model: modelName)
        let newInstance = try await WhisperKit(config)
        
        // Remove least recently used models if cache is full
        evictLeastRecentlyUsedIfNeeded(maxCached: maxCached)
        
        // Cache the new instance
        instances[modelName] = newInstance
        accessTimes[modelName] = Date()
        
        return newInstance
    }
    
    func clear() {
        instances.removeAll()
        accessTimes.removeAll()
    }
    
    func clearExceptMostRecent() {
        let sortedByAccess = accessTimes.sorted { $0.value > $1.value }
        
        // Keep only the most recent model
        for (index, model) in sortedByAccess.enumerated() {
            if index > 0 {
                instances.removeValue(forKey: model.key)
                accessTimes.removeValue(forKey: model.key)
            }
        }
    }
    
    private func evictLeastRecentlyUsedIfNeeded(maxCached: Int) {
        guard instances.count >= maxCached else { return }
        
        // Find the least recently used model
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }
        
        // Remove the oldest accessed model
        if let oldestModel = sortedByAccess.first {
            instances.removeValue(forKey: oldestModel.key)
            accessTimes.removeValue(forKey: oldestModel.key)
        }
    }
}

final class LocalWhisperService: Sendable {
    static let shared = LocalWhisperService()
    
    // Use actor isolation for thread-safe access to mutable state
    private let cache = WhisperKitCache()
    private let maxCachedModels = 3 // Limit cache to prevent excessive memory usage
    private let memoryPressureSource: DispatchSourceMemoryPressure?
    
    init() {
        // Create memory pressure source inline to avoid self reference
        let queue = DispatchQueue(label: "whisperkit.memorypressure")
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: queue)
        
        // Capture cache reference weakly to avoid retain cycle
        let weakCache = cache
        
        source.setEventHandler { [weak weakCache] in
            guard let cache = weakCache else { return }
            
            let memoryPressure = source.mask
            
            if memoryPressure.contains(.critical) {
                // Critical memory pressure - clear all cached models
                Task {
                    await cache.clear()
                }
            } else if memoryPressure.contains(.warning) {
                // Warning level - remove least recently used models aggressively
                Task {
                    await cache.clearExceptMostRecent()
                }
            }
        }
        
        source.resume()
        self.memoryPressureSource = source
    }
    
    deinit {
        memoryPressureSource?.cancel()
    }
    
    func transcribe(audioFileURL: URL, model: WhisperModel, progressCallback: (@Sendable (String) -> Void)? = nil) async throws -> String {
        let modelName = model.whisperKitModelName
        
        // Get or create WhisperKit instance from actor-isolated cache
        let whisperKit = try await cache.getOrCreate(modelName: modelName, model: model, maxCached: maxCachedModels, progressCallback: progressCallback)
        
        // Provide helpful progress messaging with duration estimate
        let durationHint = getDurationHint(for: model)
        progressCallback?("Transcribing audio... \(durationHint)")
        
        // Transcribe the audio file
        progressCallback?("Processing audio...")
        let results = try await whisperKit.transcribe(audioPath: audioFileURL.path)
        
        // Combine all transcription segments into a single text
        let transcription = results.map { $0.text }.joined(separator: " ")
        
        guard !transcription.isEmpty else {
            throw LocalWhisperError.transcriptionFailed
        }
        
        progressCallback?("Transcription complete!")
        return transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    
    // Method to clear cached instances if needed (for memory management)
    func clearCache() async {
        await cache.clear()
    }
    
    // Method to preload a specific model
    func preloadModel(_ model: WhisperModel, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        let modelName = model.whisperKitModelName
        _ = try await cache.getOrCreate(modelName: modelName, model: model, maxCached: maxCachedModels, progressCallback: progressCallback)
    }
    
    // Provide helpful duration hints based on model speed
    private func getDurationHint(for model: WhisperModel) -> String {
        switch model {
        case .tiny:
            return "This may take 30-60 seconds..."
        case .base:
            return "This may take 1-2 minutes..."
        case .small:
            return "This may take 2-3 minutes..."
        case .largeTurbo:
            return "This may take 3-5 minutes..."
        }
    }
}

enum LocalWhisperError: LocalizedError {
    case modelNotDownloaded
    case invalidAudioFile
    case bufferAllocationFailed
    case noChannelData
    case resamplingFailed
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model not downloaded. Please download the model first."
        case .invalidAudioFile:
            return "Invalid audio file format"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .noChannelData:
            return "No audio channel data found"
        case .resamplingFailed:
            return "Failed to resample audio"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}

extension WhisperModel {
    var whisperKitModelName: String {
        switch self {
        case .tiny:
            return "openai_whisper-tiny"
        case .base:
            return "openai_whisper-base"
        case .small:
            return "openai_whisper-small"
        case .largeTurbo:
            return "openai_whisper-large-v3_turbo"
        }
    }
}