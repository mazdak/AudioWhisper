import Foundation
@preconcurrency import WhisperKit
import AVFoundation

// Actor to manage WhisperKit instances safely across concurrency boundaries.
// Audit item B3: keys are the typed `WhisperModel` enum, not the raw model
// name string. The enum's `rawValue` is reserved for interfacing with
// WhisperKit's external API (e.g. `WhisperKitConfig(model:)`).
private actor WhisperKitCache {
    private var instances: [WhisperModel: WhisperKit] = [:]
    private var accessTimes: [WhisperModel: Date] = [:]

    func getOrCreate(model: WhisperModel, maxCached: Int, progressCallback: (@Sendable (String) -> Void)?) async throws -> WhisperKit {
        // Check if we have a cached instance
        if let existingInstance = instances[model] {
            // Update access time for LRU tracking
            accessTimes[model] = Date()
            return existingInstance
        }

        // Check if model is downloaded locally before attempting to create WhisperKit instance
        if !(await isModelDownloadedLocally(model)) {
            throw LocalWhisperError.modelNotDownloaded
        }

        // Create new instance
        progressCallback?("Preparing \(model.displayName) model...")

        // Set environment variables to ensure offline operation
        setenv("HF_HUB_OFFLINE", "1", 1)
        setenv("TRANSFORMERS_OFFLINE", "1", 1)
        setenv("HF_HUB_DISABLE_IMPLICIT_TOKEN", "1", 1)

        // Try to use local model path if available
        let newInstance: WhisperKit
        do {
            if let localModelPath = getLocalModelPath(for: model) {
                let config = WhisperKitConfig(modelFolder: localModelPath)
                newInstance = try await WhisperKit(config)
            } else {
                // Fallback to model name (should work if environment variables are respected).
                // `.whisperKitModelName` is the canonical name WhisperKit expects;
                // see `WhisperModel.whisperKitModelName`.
                let config = WhisperKitConfig(model: model.whisperKitModelName)
                newInstance = try await WhisperKit(config)
            }
        } catch {
            // If WhisperKit fails due to network issues, provide a more helpful error
            if error.localizedDescription.contains("offline") ||
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") {
                throw LocalWhisperError.modelNotDownloaded
            } else {
                throw error
            }
        }

        // Remove least recently used models if cache is full
        evictLeastRecentlyUsedIfNeeded(maxCached: maxCached)

        // Cache the new instance
        instances[model] = newInstance
        accessTimes[model] = Date()

        return newInstance
    }

    func clear() {
        instances.removeAll()
        accessTimes.removeAll()
    }

    func clearExceptMostRecent() {
        let sortedByAccess = accessTimes.sorted { $0.value > $1.value }

        // Keep only the most recent model
        for (index, entry) in sortedByAccess.enumerated() {
            if index > 0 {
                instances.removeValue(forKey: entry.key)
                accessTimes.removeValue(forKey: entry.key)
            }
        }
    }

    private func evictLeastRecentlyUsedIfNeeded(maxCached: Int) {
        guard instances.count >= maxCached else { return }

        // Find the least recently used model
        let sortedByAccess = accessTimes.sorted { $0.value < $1.value }

        // Remove the oldest accessed model
        if let oldest = sortedByAccess.first {
            instances.removeValue(forKey: oldest.key)
            accessTimes.removeValue(forKey: oldest.key)
        }
    }

    private func isModelDownloadedLocally(_ model: WhisperModel) async -> Bool {
        WhisperKitStorage.isModelDownloaded(model)
    }

    private func getLocalModelPath(for model: WhisperModel) -> String? {
        WhisperKitStorage.localModelPath(for: model)
    }
}

internal final class LocalWhisperService: Sendable {
    static let shared = LocalWhisperService()

    /// Default model used when the stored `selectedWhisperModel` value is missing
    /// or doesn't match a known `WhisperModel` case. Mirrors `AppDefaults.selectedWhisperModel`.
    static let defaultModel: WhisperModel = .base

    /// Reads the persisted `selectedWhisperModel` and returns a `WhisperModel`,
    /// falling back to `defaultModel` if the stored value is empty or no longer
    /// matches a known enum case. Delegates to `AppDefaults.selectedWhisperModel`,
    /// which already validates against the enum and falls back to `.base`
    /// (== `defaultModel`).
    static var safeSelectedWhisperModel: WhisperModel {
        AppDefaults.selectedWhisperModel
    }

    // Use actor isolation for thread-safe access to mutable state
    private let cache = WhisperKitCache()
    private let maxCachedModels = 3 // Limit cache to prevent excessive memory usage
    private let memoryPressureSource: DispatchSourceMemoryPressure?
    
    init() {
        // Create memory pressure source inline to avoid self reference
        let queue = DispatchQueue(label: "whisperkit.memorypressure")
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: queue)

        // Capture cache reference for use in the event handler
        // The cache is an actor (reference type), so we capture it directly.
        // Since LocalWhisperService owns the cache and source, the lifecycle is properly managed.
        let cacheRef = cache

        source.setEventHandler {
            let memoryPressure = source.mask

            if memoryPressure.contains(.critical) {
                // Critical memory pressure - clear all cached models
                Task {
                    await cacheRef.clear()
                }
            } else if memoryPressure.contains(.warning) {
                // Warning level - remove least recently used models aggressively
                Task {
                    await cacheRef.clearExceptMostRecent()
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
        // Get or create WhisperKit instance from actor-isolated cache.
        // Audit item B3: cache is keyed by the typed `WhisperModel`; the raw
        // model name is only used internally when constructing `WhisperKitConfig`.
        let whisperKit = try await cache.getOrCreate(model: model, maxCached: maxCachedModels, progressCallback: progressCallback)

        // Provide helpful progress messaging with duration estimate
        let durationHint = getDurationHint(for: model)
        progressCallback?("Transcribing audio... \(durationHint)")

        // Configure decoding options for transcription (not translation)
        // task: .transcribe ensures X→X speech recognition (preserves original language)
        // task: .translate would perform X→English translation
        var decodingOptions = DecodingOptions()
        decodingOptions.task = .transcribe
        // Let WhisperKit auto-detect the language
        decodingOptions.language = nil

        // Transcribe the audio file
        progressCallback?("Processing audio...")
        let results = try await whisperKit.transcribe(audioPath: audioFileURL.path, decodeOptions: decodingOptions)

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
        _ = try await cache.getOrCreate(model: model, maxCached: maxCachedModels, progressCallback: progressCallback)
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

internal enum LocalWhisperError: LocalizedError {
    case modelNotDownloaded
    case invalidAudioFile
    case bufferAllocationFailed
    case noChannelData
    case resamplingFailed
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Whisper model not downloaded. Please download the model in Settings before using offline transcription."
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
