import Foundation
import os.log
import AudioToolbox

enum ParakeetError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case scriptNotFound
    case transcriptionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python executable not found at: \(path)\n\nTry:\n• Use system Python: /usr/bin/python3\n• Install via Homebrew: brew install python3\n• Check if path exists and is executable"
        case .scriptNotFound:
            return "Parakeet transcription script not found in app bundle"
        case .transcriptionFailed(let message):
            return "Parakeet transcription failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Parakeet: \(message)"
        case .dependencyMissing(let dependency, let installCommand):
            return "\(dependency) is not installed\n\nInstall with: \(installCommand)"
        case .processTimedOut(let timeout):
            return "Transcription timed out after \(timeout) seconds\n\nTry with a shorter audio file or check system resources"
        }
    }
}

struct ParakeetResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

class ParakeetService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ParakeetService")
    
    func transcribe(audioFileURL: URL, pythonPath: String) async throws -> String {
        
        // Step 1: Process audio with Swift AudioProcessor to create raw PCM data
        let pcmDataURL = try await processAudioToRawPCM(audioFileURL: audioFileURL)
        defer {
            // Clean up the temporary PCM file
            try? FileManager.default.removeItem(at: pcmDataURL)
        }
        
        // Step 2: Call Python with the raw PCM data instead of original audio
        return try await transcribeWithRawPCM(pcmDataURL: pcmDataURL, pythonPath: pythonPath)
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
    
    private func transcribeWithRawPCM(pcmDataURL: URL, pythonPath: String) async throws -> String {
        // Validate Python path
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw ParakeetError.pythonNotFound(path: pythonPath)
        }
        
        // Test Python interpreter
        let testProcess = Process()
        testProcess.executableURL = URL(fileURLWithPath: pythonPath)
        testProcess.arguments = ["-c", "import sys; print(f'Python {sys.version} at {sys.executable}'); import parakeet_mlx; print('parakeet-mlx is available')"]
        let testPipe = Pipe()
        testProcess.standardOutput = testPipe
        testProcess.standardError = testPipe
        
        do {
            try testProcess.run()
            testProcess.waitUntilExit()
            let testData = testPipe.fileHandleForReading.readDataToEndOfFile()
            _ = String(data: testData, encoding: .utf8) ?? ""
            
            if testProcess.terminationStatus != 0 {
                throw ParakeetError.pythonNotFound(path: pythonPath)
            }
        } catch {
            throw ParakeetError.pythonNotFound(path: pythonPath)
        }
        
        // Get the Parakeet PCM script path from bundle or source directory
        var scriptURL: URL?
        
        // First try to find the PCM script in the app bundle (production)
        scriptURL = Bundle.main.url(forResource: "parakeet_transcribe_pcm", withExtension: "py")
        
        // If not found, try development fallback (swift run)
        if scriptURL == nil {
            let currentDir = FileManager.default.currentDirectoryPath
            let sourceScriptPath = "\(currentDir)/Sources/parakeet_transcribe_pcm.py"
            if FileManager.default.fileExists(atPath: sourceScriptPath) {
                scriptURL = URL(fileURLWithPath: sourceScriptPath)
            }
        }
        
        guard let scriptURL = scriptURL else {
            throw ParakeetError.scriptNotFound
        }
        
        // Create a temporary copy of the script with the correct shebang
        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet_transcribe_pcm_\(UUID().uuidString).py")
        
        do {
            // Read the original script
            var scriptContent = try String(contentsOf: scriptURL, encoding: .utf8)
            
            // Replace the shebang with the user's Python path
            if scriptContent.hasPrefix("#!") {
                let lines = scriptContent.components(separatedBy: .newlines)
                if !lines.isEmpty {
                    var modifiedLines = lines
                    modifiedLines[0] = "#!\(pythonPath)"
                    scriptContent = modifiedLines.joined(separator: "\n")
                }
            }
            
            // Write the modified script
            try scriptContent.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            
            // Ensure we clean up the temp script
            defer {
                try? FileManager.default.removeItem(at: tempScriptURL)
            }
            
            // Run the Python script asynchronously
            let (outputString, errorString, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String, Int32), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)
                
                process.arguments = [tempScriptURL.path, pcmDataURL.path]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                // Set up timeout handling (30 seconds for transcription)
                let timeoutTask = Task {
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: ParakeetError.processTimedOut(30))
                    }
                }
                
                // Set up process completion handler
                process.terminationHandler = { process in
                    timeoutTask.cancel()
                    
                    // Read output after process completes
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let outputString = String(data: outputData, encoding: .utf8) ?? ""
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""
                    
                    continuation.resume(returning: (outputString, errorString, process.terminationStatus))
                }
                
                do {
                    try process.run()
                } catch {
                    timeoutTask.cancel()
                    continuation.resume(throwing: error)
                }
            }
            
            if terminationStatus != 0 {
                logger.error("Parakeet process failed with status: \(terminationStatus)")
                logger.error("Error output: \(errorString)")
                
                // Provide more specific error handling
                logger.error("Python script failed with error: \(errorString)")
                logger.error("Termination status: \(terminationStatus)")
                
                if errorString.contains("parakeet_mlx") || errorString.contains("ModuleNotFoundError") {
                    throw ParakeetError.dependencyMissing("parakeet-mlx", installCommand: "pip install parakeet-mlx")
                } else {
                    throw ParakeetError.transcriptionFailed(errorString.isEmpty ? "Process exited with status \(terminationStatus)" : errorString)
                }
            }
            
            // Parse the JSON response
            guard let responseData = outputString.data(using: String.Encoding.utf8) else {
                throw ParakeetError.invalidResponse("Empty output")
            }
            
            let response = try JSONDecoder().decode(ParakeetResponse.self, from: responseData)
            
            if response.success {
                logger.info("Parakeet transcription successful")
                return response.text
            } else {
                throw ParakeetError.transcriptionFailed(response.error ?? "Unknown error")
            }
            
        } catch {
            logger.error("Parakeet transcription error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func validateSetup(pythonPath: String) async throws {
        // Check if Python exists
        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw ParakeetError.pythonNotFound(path: pythonPath)
        }
        
        // Check if parakeet_mlx is installed using async process execution
        let (_, terminationStatus) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, Int32), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = ["-c", "import parakeet_mlx; print('OK')"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            // Set up timeout for validation (10 seconds)
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if process.isRunning {
                    process.terminate()
                    continuation.resume(throwing: ParakeetError.processTimedOut(10))
                }
            }
            
            process.terminationHandler = { process in
                timeoutTask.cancel()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (output, process.terminationStatus))
            }
            
            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: error)
            }
        }
        
        if terminationStatus != 0 {
            throw ParakeetError.dependencyMissing("parakeet-mlx", installCommand: "pip install parakeet-mlx")
        }
    }
}