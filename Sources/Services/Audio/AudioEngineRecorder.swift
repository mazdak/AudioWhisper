import Accelerate
import AVFoundation
import Combine
import Foundation
import os.log

/// Audio recorder using AVAudioEngine for real-time sample access.
/// Provides raw waveform samples and frequency data for enhanced visualizations.
@MainActor
final class AudioEngineRecorder: NSObject, ObservableObject, AudioRecording {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published private(set) var waveformSamples: [Float] = []
    @Published private(set) var frequencyBands: [Float] = Array(repeating: 0, count: 8)

    // MARK: - Recording State

    private(set) var currentSessionStart: Date?
    private(set) var lastRecordingDuration: TimeInterval?

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    // MARK: - Processing

    private let fftProcessor: FFTProcessor?
    private var sampleBuffer: [Float] = []
    private let sampleBufferSize = 2048
    private let dateProvider: () -> Date
    private let sampleBufferLock = NSLock()  // Lock for thread-safe sampleBuffer access from audio thread
    private var writeErrorCount = 0  // Track write errors for diagnostics

    // MARK: - Volume Management

    private let volumeManager: MicrophoneVolumeManaging

    // MARK: - Initialization

    override init() {
        self.fftProcessor = FFTProcessor()
        self.volumeManager = MicrophoneVolumeManager.shared
        self.dateProvider = { Date() }
        super.init()
    }

    init(
        volumeManager: MicrophoneVolumeManaging = MicrophoneVolumeManager.shared,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.fftProcessor = FFTProcessor()
        self.volumeManager = volumeManager
        self.dateProvider = dateProvider
        super.init()
    }

    // MARK: - AudioRecording Protocol

    func startRecording() -> Bool {
        // Check permission via PermissionManager (single source of truth)
        guard PermissionManager.shared.microphonePermissionState == .granted else {
            return false
        }

        // Prevent re-entrancy
        guard audioEngine == nil else {
            return false
        }

        // Boost microphone volume if enabled
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.boostMicrophoneVolume()
            }
        }

        // Skip real audio hardware operations in test environment to prevent errors
        if AppEnvironment.isRunningTests {
            return false
        }

        // Create recording URL
        let tempPath = FileManager.default.temporaryDirectory
        let timestamp = dateProvider().timeIntervalSince1970
        let audioFilename = tempPath.appendingPathComponent("recording_\(timestamp).m4a")
        recordingURL = audioFilename

        do {
            // Set up audio engine
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Create output file for recording
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioFile = try AVAudioFile(
                forWriting: audioFilename,
                settings: outputSettings
            )

            // Install tap for real-time audio access
            let bufferSize = AVAudioFrameCount(1024)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

            // Start the engine
            try engine.start()

            audioEngine = engine
            currentSessionStart = dateProvider()
            lastRecordingDuration = nil
            writeErrorCount = 0  // Reset error count for new session
            isRecording = true

            return true

        } catch {
            Logger.audioEngineRecorder.error("Failed to start engine recording: \(error.localizedDescription)")

            // Clear recordingURL to prevent orphaned file reference
            recordingURL = nil

            // Restore volume if recording failed
            if UserDefaults.standard.autoBoostMicrophoneVolume {
                Task {
                    await volumeManager.restoreMicrophoneVolume()
                }
            }

            // Recheck permissions
            PermissionManager.shared.checkPermissionState()
            return false
        }
    }

    func stopRecording() -> URL? {
        let now = dateProvider()
        let sessionDuration = currentSessionStart.map { now.timeIntervalSince($0) }
        lastRecordingDuration = sessionDuration
        currentSessionStart = nil

        // Log warning if write errors occurred during recording
        if writeErrorCount > 0 {
            Logger.audioEngineRecorder.warning("Recording had \(self.writeErrorCount) audio buffer write errors - audio may be incomplete")
        }

        stopEngine()

        // Restore microphone volume if it was boosted
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.restoreMicrophoneVolume()
            }
        }

        isRecording = false
        clearVisualizationData()

        return recordingURL
    }

    func cancelRecording() {
        currentSessionStart = nil
        lastRecordingDuration = nil

        stopEngine()

        // Restore microphone volume
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.restoreMicrophoneVolume()
            }
        }

        isRecording = false
        clearVisualizationData()
        cleanupRecording()
    }

    func cleanupRecording() {
        guard let url = recordingURL else { return }

        currentSessionStart = nil
        lastRecordingDuration = nil

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Skip logging in tests to reduce console noise
            if !AppEnvironment.isRunningTests {
                Logger.audioEngineRecorder.error("Failed to cleanup recording file: \(error.localizedDescription)")
            }
        }

        recordingURL = nil
    }

    // MARK: - Private Methods

    private func stopEngine() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        // AVAudioFile flushes buffers on dealloc. Explicitly nil to trigger
        // immediate deallocation and flush before caller processes the file.
        // Note: If there are other references, dealloc may be delayed.
        audioFile = nil
    }

    private func clearVisualizationData() {
        audioLevel = 0.0
        waveformSamples = []
        frequencyBands = Array(repeating: 0, count: 8)
        // Use lock for thread-safe sampleBuffer access
        sampleBufferLock.lock()
        sampleBuffer.removeAll()
        sampleBufferLock.unlock()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Convert to mono by averaging channels
        var monoSamples = [Float](repeating: 0, count: frameLength)

        if channelCount == 1 {
            // Already mono
            monoSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            // Average channels
            for i in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][i]
                }
                monoSamples[i] = sum / Float(channelCount)
            }
        }

        // Write to file (on audio thread for performance)
        if let audioFile = audioFile {
            do {
                try audioFile.write(from: buffer)
            } catch {
                // Track write errors for later reporting
                writeErrorCount += 1
                if writeErrorCount == 1 {
                    // Only log the first error to avoid log spam
                    Logger.audioEngineRecorder.error("Failed to write audio buffer: \(error.localizedDescription)")
                }
            }
        }

        // Use lock for thread-safe sampleBuffer access (called from audio thread)
        // This implements a bounded circular buffer pattern:
        // - Append new samples
        // - If buffer exceeds max size, remove oldest samples to maintain fixed size
        // - Maximum size is sampleBufferSize (2048 samples = ~128ms at 16kHz)
        sampleBufferLock.lock()
        sampleBuffer.append(contentsOf: monoSamples)
        let overflow = sampleBuffer.count - sampleBufferSize
        if overflow > 0 {
            // Use suffix to efficiently keep only the most recent samples
            sampleBuffer = Array(sampleBuffer.suffix(sampleBufferSize))
        }
        let currentBuffer = sampleBuffer
        sampleBufferLock.unlock()

        // Calculate audio level and frequency bands (graceful fallback if FFT unavailable)
        let level = fftProcessor?.calculateLevel(from: monoSamples) ?? 0.0
        let bands = fftProcessor?.process(currentBuffer) ?? Array(repeating: 0, count: 8)

        // Downsample waveform for display (reduce to ~128 points)
        let displaySamples = downsampleForDisplay(currentBuffer, targetCount: 128)

        // Update published properties on main thread
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.audioLevel = level
            self.frequencyBands = bands
            self.waveformSamples = displaySamples
        }
    }

    private func downsampleForDisplay(_ samples: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 0, samples.count > targetCount else { return samples }

        let chunkSize = samples.count / targetCount
        var result = [Float](repeating: 0, count: targetCount)

        for i in 0..<targetCount {
            let startIndex = i * chunkSize
            let endIndex = min(startIndex + chunkSize, samples.count)
            let chunk = Array(samples[startIndex..<endIndex])

            // Use RMS for each chunk
            var rms: Float = 0
            vDSP_rmsqv(chunk, 1, &rms, vDSP_Length(chunk.count))
            result[i] = rms
        }

        return result
    }
}

// MARK: - Logger Extension

private extension Logger {
    static let audioEngineRecorder = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AudioWhisper", category: "AudioEngineRecorder")
}
