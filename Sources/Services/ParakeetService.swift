import Foundation
import os.log
import AudioToolbox

internal enum ParakeetError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case scriptNotFound
    case transcriptionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    case modelNotReady
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python runtime not available at: \(path)\n\nFix:\n• Open Settings ▸ Parakeet ▸ Install/Update Dependencies with uv"
        case .scriptNotFound:
            return "Parakeet transcription script not found in app bundle"
        case .transcriptionFailed(let message):
            return "Parakeet transcription failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Parakeet: \(message)"
        case .dependencyMissing(let dependency, _):
            return "\(dependency) is not installed\n\nFix: Open Settings ▸ Parakeet ▸ Install/Update Dependencies with uv"
        case .processTimedOut(let timeout):
            return "Transcription timed out after \(timeout) seconds\n\nTry with a shorter audio file or check system resources"
        case .modelNotReady:
            return "Parakeet model not downloaded. Open Settings ▸ Parakeet to download it."
        }
    }
}

internal struct ParakeetResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

internal class ParakeetService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ParakeetService")
    private let daemon = MLDaemonManager.shared

    func transcribe(audioFileURL: URL, pythonPath _: String? = nil) async throws -> String {
        // Step 0: Do not download here; just verify model cache exists
        guard isModelCached() else {
            throw ParakeetError.modelNotReady
        }

        // Step 1: Process audio with Swift AudioProcessor to create raw PCM data
        let pcmDataURL = try await processAudioToRawPCM(audioFileURL: audioFileURL)
        defer {
            // Clean up the temporary PCM file
            try? FileManager.default.removeItem(at: pcmDataURL)
        }
        
        // Step 2: Call Python with the raw PCM data instead of original audio
        return try await transcribeWithRawPCM(pcmDataURL: pcmDataURL)
    }

    private var selectedRepo: String {
        UserDefaults.standard.string(forKey: "selectedParakeetModel") ?? ParakeetModel.v3Multilingual.rawValue
    }

    private func isModelCached() -> Bool {
        let repo = selectedRepo
        let escaped = repo.replacingOccurrences(of: "/", with: "--")
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--\(escaped)")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: base.path, isDirectory: &isDir), isDir.boolValue else { return false }
        let refsMain = base.appendingPathComponent("refs/main")
        guard let rev = try? String(contentsOf: refsMain, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !rev.isEmpty else {
            return false
        }
        let snap = base.appendingPathComponent("snapshots/\(rev)")
        guard FileManager.default.fileExists(atPath: snap.path, isDirectory: &isDir), isDir.boolValue else { return false }
        // Look for at least one weights file under snapshot or blobs
        let snapFiles = (try? FileManager.default.contentsOfDirectory(atPath: snap.path)) ?? []
        let blobsFiles = (try? FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent("blobs").path)) ?? []
        let hasWeights = snapFiles.contains { $0.hasSuffix(".safetensors") } || blobsFiles.contains { $0.hasSuffix(".safetensors") }
        return hasWeights
    }
    
    private func processAudioToRawPCM(audioFileURL: URL) async throws -> URL {
        // Create temporary file for raw PCM data
        let tempPCMURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_pcm_\(UUID().uuidString).raw")
        
        do {
            // Use AudioProcessor.swift logic directly
            let samples = try loadAudio(url: audioFileURL, samplingRate: 16000)
            
            // Write raw float32 data
            let data = Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
            try data.write(to: tempPCMURL)
            
            return tempPCMURL
            
        } catch {
            throw ParakeetError.transcriptionFailed("Audio processing failed: \(error.localizedDescription)")
        }
    }
    
    // Audio processing function from AudioProcessor.swift
    private func loadAudio(url: URL, samplingRate: Int) throws -> [Float] {
        var extAudioFile: ExtAudioFileRef?
        
        // Open the audio file
        var status = ExtAudioFileOpenURL(url as CFURL, &extAudioFile)
        guard status == noErr, let extFile = extAudioFile else {
            throw ParakeetError.transcriptionFailed("Failed to open audio file: \(status)")
        }
        defer { ExtAudioFileDispose(extFile) }
        
        // Get file's original format and length
        var fileFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(extFile, kExtAudioFileProperty_FileDataFormat, &propertySize, &fileFormat)
        guard status == noErr else {
            throw ParakeetError.transcriptionFailed("Failed to get audio format: \(status)")
        }
        
        var fileLengthFrames: Int64 = 0
        propertySize = UInt32(MemoryLayout<Int64>.size)
        status = ExtAudioFileGetProperty(extFile, kExtAudioFileProperty_FileLengthFrames, &propertySize, &fileLengthFrames)
        guard status == noErr else {
            throw ParakeetError.transcriptionFailed("Failed to get audio length: \(status)")
        }
        
        // Define client format: mono, float32, target sample rate, interleaved/packed
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: Float64(samplingRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        
        propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileSetProperty(extFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &clientFormat)
        guard status == noErr else {
            throw ParakeetError.transcriptionFailed("Failed to set audio format: \(status)")
        }
        
        // Estimate client length for preallocation
        let fileSampleRate = fileFormat.mSampleRate
        let duration = Double(fileLengthFrames) / fileSampleRate
        let estimatedClientFrames = Int(duration * Double(samplingRate) + 0.5)
        var samples: [Float] = []
        samples.reserveCapacity(estimatedClientFrames)
        
        // Read in chunks until EOF
        let bufferFrameSize = 4096
        var buffer = [Float](repeating: 0, count: bufferFrameSize)
        
        while true {
            var numFrames = UInt32(bufferFrameSize)
            
            let audioBuffer = buffer.withUnsafeMutableBytes { bytes in
                AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(bufferFrameSize * MemoryLayout<Float>.size),
                    mData: bytes.baseAddress
                )
            }
            var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
            
            status = ExtAudioFileRead(extFile, &numFrames, &audioBufferList)
            guard status == noErr else {
                throw ParakeetError.transcriptionFailed("Failed to read audio data: \(status)")
            }
            
            if numFrames == 0 {
                break  // EOF
            }
            
            samples.append(contentsOf: buffer[0..<Int(numFrames)])
        }
        
        return samples
    }
    
    private func transcribeWithRawPCM(pcmDataURL: URL) async throws -> String {
        do {
            let text = try await daemon.transcribe(repo: selectedRepo, pcmPath: pcmDataURL.path)
            logger.info("Parakeet transcription successful")
            return text
        } catch {
            logger.error("Parakeet transcription error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func validateSetup(pythonPath _: String? = nil) async throws {
        guard isModelCached() else {
            throw ParakeetError.modelNotReady
        }

        do {
            try await daemon.warmup(type: "parakeet", repo: selectedRepo)
        } catch {
            logger.error("Parakeet warmup failed: \(error.localizedDescription)")
            throw ParakeetError.transcriptionFailed("Parakeet daemon unavailable: \(error.localizedDescription)")
        }
    }
}
