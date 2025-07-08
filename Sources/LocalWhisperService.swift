import Foundation
@preconcurrency import WhisperKit
import AVFoundation

class LocalWhisperService: @unchecked Sendable {
    static let shared = LocalWhisperService()
    private var whisperKitInstances: [String: WhisperKit] = [:]
    private var modelAccessTimes: [String: Date] = [:]
    private let instanceQueue = DispatchQueue(label: "whisperkit.instances", attributes: .concurrent)
    private let maxCachedModels = 3 // Limit cache to prevent excessive memory usage
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    init() {
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        memoryPressureSource?.cancel()
    }
    
    func transcribe(audioFileURL: URL, model: WhisperModel, progressCallback: (@Sendable (String) -> Void)? = nil) async throws -> String {
        let modelName = model.whisperKitModelName
        
        // Check if we have a cached instance
        let whisperKit = try await getOrCreateWhisperKit(modelName: modelName, model: model, progressCallback: progressCallback)
        
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
    
    private func getOrCreateWhisperKit(modelName: String, model: WhisperModel, progressCallback: (@Sendable (String) -> Void)? = nil) async throws -> WhisperKit {
        return try await withCheckedThrowingContinuation { continuation in
            instanceQueue.async(flags: .barrier) {
                if let existingInstance = self.whisperKitInstances[modelName] {
                    // Update access time for LRU tracking
                    self.modelAccessTimes[modelName] = Date()
                    continuation.resume(returning: existingInstance)
                    return
                }
                
                Task {
                    do {
                        // Always show loading message since we can't easily check if model is local
                        progressCallback?("Preparing \(model.displayName) model...")
                        
                        let config = WhisperKitConfig(model: modelName)
                        let newInstance = try await WhisperKit(config)
                        
                        // Cache the instance with LRU management
                        self.instanceQueue.async(flags: .barrier) {
                            // Remove least recently used models if cache is full
                            self.evictLeastRecentlyUsedIfNeeded()
                            
                            self.whisperKitInstances[modelName] = newInstance
                            self.modelAccessTimes[modelName] = Date()
                        }
                        
                        continuation.resume(returning: newInstance)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // Method to clear cached instances if needed (for memory management)
    func clearCache() {
        instanceQueue.async(flags: .barrier) {
            self.whisperKitInstances.removeAll()
            self.modelAccessTimes.removeAll()
        }
    }
    
    private func evictLeastRecentlyUsedIfNeeded() {
        // This method should be called from within a barrier block
        guard whisperKitInstances.count >= maxCachedModels else { return }
        
        // Find the least recently used model
        let sortedByAccess = modelAccessTimes.sorted { $0.value < $1.value }
        
        // Remove the oldest accessed model
        if let oldestModel = sortedByAccess.first {
            whisperKitInstances.removeValue(forKey: oldestModel.key)
            modelAccessTimes.removeValue(forKey: oldestModel.key)
        }
    }
    
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: instanceQueue)
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let memoryPressure = source.mask
            
            if memoryPressure.contains(.critical) {
                // Critical memory pressure - clear all cached models
                self.instanceQueue.async(flags: .barrier) {
                    self.whisperKitInstances.removeAll()
                    self.modelAccessTimes.removeAll()
                }
            } else if memoryPressure.contains(.warning) {
                // Warning level - remove least recently used models aggressively
                self.instanceQueue.async(flags: .barrier) {
                    // Remove all but the most recently used model
                    let sortedByAccess = self.modelAccessTimes.sorted { $0.value > $1.value }
                    
                    // Keep only the most recent model
                    for (index, model) in sortedByAccess.enumerated() {
                        if index > 0 {
                            self.whisperKitInstances.removeValue(forKey: model.key)
                            self.modelAccessTimes.removeValue(forKey: model.key)
                        }
                    }
                }
            }
        }
        
        source.resume()
        memoryPressureSource = source
    }
    
    // Method to preload a specific model
    func preloadModel(_ model: WhisperModel, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        let modelName = model.whisperKitModelName
        _ = try await getOrCreateWhisperKit(modelName: modelName, model: model, progressCallback: progressCallback)
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