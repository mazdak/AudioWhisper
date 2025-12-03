import Foundation
import AVFoundation

/// Service for validating audio files and detecting corruption
class AudioValidator {
    
    // MARK: - Supported Formats
    
    private static let supportedFileExtensions: Set<String> = [
        "m4a", "aac", "mp3", "wav", "aiff", "caf", "flac"
    ]

    private static let supportedMimeTypes: Set<String> = [
        "audio/mp4", "audio/aac", "audio/mpeg", "audio/wav",
        "audio/x-wav", "audio/aiff", "audio/x-caf", "audio/flac"
    ]
    
    // MARK: - Validation Methods
    
    /// Validates an audio file for format compatibility and corruption
    /// - Parameter url: URL of the audio file to validate
    /// - Returns: Validation result with details
    static func validateAudioFile(at url: URL) async -> AudioValidationResult {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .invalid(.fileNotFound)
        }
        
        // Check file size (empty files are invalid)
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64,
              fileSize > 0 else {
            return .invalid(.emptyFile)
        }
        
        // Check file extension
        let fileExtension = url.pathExtension.lowercased()
        guard supportedFileExtensions.contains(fileExtension) else {
            return .invalid(.unsupportedFormat(fileExtension))
        }
        
        // Validate with AVFoundation
        return await validateWithAVFoundation(url: url)
    }
    
    /// Quick format check without deep validation
    /// - Parameter url: URL to check
    /// - Returns: True if format appears supported
    static func isFormatSupported(url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedFileExtensions.contains(fileExtension)
    }
    
    /// Check maximum file size for processing
    /// - Parameters:
    ///   - url: URL to check
    ///   - maxSizeInMB: Maximum allowed size in megabytes
    /// - Returns: True if file is within size limits
    static func isFileSizeValid(url: URL, maxSizeInMB: Int = 100) -> Bool {
        guard let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 else {
            return false
        }
        let maxSizeInBytes = Int64(maxSizeInMB * 1024 * 1024)
        return fileSize <= maxSizeInBytes
    }
    
    // MARK: - Private Methods
    
    private static func validateWithAVFoundation(url: URL) async -> AudioValidationResult {
        // Try to create AVURLAsset
        let asset = AVURLAsset(url: url)
        
        // Check if asset can be loaded (using async API)
        let isReadable: Bool
        do {
            isReadable = try await asset.load(.isReadable)
        } catch {
            return .invalid(.corruptedFile)
        }
        
        guard isReadable else {
            return .invalid(.corruptedFile)
        }
        
        // Try to get audio tracks (using async API)
        let audioTracks: [AVAssetTrack]
        do {
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            return .invalid(.corruptedFile)
        }
        
        guard !audioTracks.isEmpty else {
            return .invalid(.noAudioTracks)
        }
        
        // Validate the first audio track
        let track = audioTracks[0]
        
        // Check track format descriptions (using async API)
        let formatDescriptions: [CMFormatDescription]
        do {
            formatDescriptions = try await track.load(.formatDescriptions)
        } catch {
            return .invalid(.corruptedFile)
        }
        
        guard !formatDescriptions.isEmpty else {
            return .invalid(.invalidAudioFormat)
        }
            
        // Try to create AVAudioFile to ensure it's readable
        do {
            let audioFile = try AVAudioFile(forReading: url)
            
            // Validate basic properties
            let format = audioFile.fileFormat
            
            // Check sample rate (must be positive)
            guard format.sampleRate > 0 else {
                return .invalid(.invalidSampleRate)
            }
            
            // Check channel count (must be positive)
            guard format.channelCount > 0 else {
                return .invalid(.invalidChannelCount)
            }
            
            // Check file length
            guard audioFile.length > 0 else {
                return .invalid(.emptyAudio)
            }
            
            // Try to read a small sample to detect corruption
            let frameCapacity = min(4096, AVAudioFrameCount(audioFile.length))
            if let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCapacity) {
                try audioFile.read(into: buffer)
            }
            
            return .valid(AudioFileInfo(
                format: format,
                duration: Double(audioFile.length) / format.sampleRate,
                fileSize: try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            ))
            
        } catch {
            return .invalid(.corruptedFile)
        }
    }
}

// MARK: - Result Types

enum AudioValidationResult {
    case valid(AudioFileInfo)
    case invalid(AudioValidationError)
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
}

enum AudioValidationError: LocalizedError {
    case fileNotFound
    case emptyFile
    case unsupportedFormat(String)
    case corruptedFile
    case noAudioTracks
    case invalidAudioFormat
    case invalidSampleRate
    case invalidChannelCount
    case emptyAudio
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("audio_validation.file_not_found", 
                value: "Audio file not found", 
                comment: "Error when audio file doesn't exist")
        case .emptyFile:
            return NSLocalizedString("audio_validation.empty_file", 
                value: "Audio file is empty", 
                comment: "Error when audio file has no data")
        case .unsupportedFormat(let format):
            return String(format: NSLocalizedString("audio_validation.unsupported_format", 
                value: "Unsupported audio format: %@", 
                comment: "Error when audio format is not supported"), format)
        case .corruptedFile:
            return NSLocalizedString("audio_validation.corrupted_file", 
                value: "Audio file is corrupted or unreadable", 
                comment: "Error when audio file is corrupted")
        case .noAudioTracks:
            return NSLocalizedString("audio_validation.no_audio_tracks", 
                value: "No audio tracks found in file", 
                comment: "Error when file has no audio content")
        case .invalidAudioFormat:
            return NSLocalizedString("audio_validation.invalid_audio_format", 
                value: "Invalid audio format", 
                comment: "Error when audio format is invalid")
        case .invalidSampleRate:
            return NSLocalizedString("audio_validation.invalid_sample_rate", 
                value: "Invalid audio sample rate", 
                comment: "Error when audio sample rate is invalid")
        case .invalidChannelCount:
            return NSLocalizedString("audio_validation.invalid_channel_count", 
                value: "Invalid audio channel count", 
                comment: "Error when audio channel count is invalid")
        case .emptyAudio:
            return NSLocalizedString("audio_validation.empty_audio", 
                value: "Audio file contains no audio data", 
                comment: "Error when audio file has no actual audio content")
        }
    }
}

struct AudioFileInfo {
    let format: AVAudioFormat
    let duration: TimeInterval
    let fileSize: Int64
    
    var sampleRate: Double {
        return format.sampleRate
    }
    
    var channelCount: UInt32 {
        return format.channelCount
    }
    
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}