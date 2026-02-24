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
        if let liveText = await ParakeetLiveTranscriber.shared.finalizeIfAvailable(expectedRepo: selectedRepo) {
            logger.info("Parakeet live stream finalize successful")
            return liveText
        }

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
        let startedAt = Date()
        defer {
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.debug("audio_convert_write_ms=\(elapsedMs, privacy: .public)")
        }

        let tempPCMURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_pcm_\(UUID().uuidString).raw")

        do {
            guard FileManager.default.createFile(atPath: tempPCMURL.path, contents: nil) else {
                throw ParakeetError.transcriptionFailed("Failed to create temporary PCM file")
            }

            let outputHandle = try FileHandle(forWritingTo: tempPCMURL)
            defer { outputHandle.closeFile() }

            var extAudioFile: ExtAudioFileRef?
            var status = ExtAudioFileOpenURL(audioFileURL as CFURL, &extAudioFile)
            guard status == noErr, let extFile = extAudioFile else {
                throw ParakeetError.transcriptionFailed("Failed to open audio file: \(status)")
            }
            defer { ExtAudioFileDispose(extFile) }

            // Convert directly to the PCM format expected by parakeet_mlx (mono, float32, 16kHz).
            var clientFormat = AudioStreamBasicDescription(
                mSampleRate: 16_000,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 32,
                mReserved: 0
            )

            let propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            status = ExtAudioFileSetProperty(extFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &clientFormat)
            guard status == noErr else {
                throw ParakeetError.transcriptionFailed("Failed to set audio format: \(status)")
            }

            let bufferFrameSize = 16_384
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

                if numFrames == 0 { break }

                try buffer.withUnsafeBytes { rawBytes in
                    guard let baseAddress = rawBytes.baseAddress else {
                        throw ParakeetError.transcriptionFailed("Audio buffer unavailable")
                    }
                    let byteCount = Int(numFrames) * MemoryLayout<Float>.size
                    let chunk = Data(bytes: baseAddress, count: byteCount)
                    try outputHandle.write(contentsOf: chunk)
                }
            }

            return tempPCMURL
        } catch {
            try? FileManager.default.removeItem(at: tempPCMURL)
            if let parakeetError = error as? ParakeetError {
                throw parakeetError
            }
            throw ParakeetError.transcriptionFailed("Audio processing failed: \(error.localizedDescription)")
        }
    }
    
    private func transcribeWithRawPCM(pcmDataURL: URL) async throws -> String {
        let startedAt = Date()
        defer {
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            logger.debug("daemon_transcribe_ms=\(elapsedMs, privacy: .public)")
        }
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

#if DEBUG
internal extension ParakeetService {
    func processAudioToRawPCMForTesting(audioFileURL: URL) async throws -> URL {
        try await processAudioToRawPCM(audioFileURL: audioFileURL)
    }

    func transcribeAndCleanupForTesting(audioFileURL: URL) async throws -> (text: String, pcmPath: String) {
        let pcmDataURL = try await processAudioToRawPCM(audioFileURL: audioFileURL)
        defer { try? FileManager.default.removeItem(at: pcmDataURL) }
        let text = try await transcribeWithRawPCM(pcmDataURL: pcmDataURL)
        return (text, pcmDataURL.path)
    }
}
#endif
