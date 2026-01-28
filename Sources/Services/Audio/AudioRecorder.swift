import Foundation
import AVFoundation
import Combine
import os.log

@MainActor
internal class AudioRecorder: NSObject, ObservableObject, AudioRecording {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelUpdateTimer: Timer?
    private let volumeManager: MicrophoneVolumeManaging
    private let recorderFactory: (URL, [String: Any]) throws -> AVAudioRecorder
    private let dateProvider: () -> Date
    private(set) var currentSessionStart: Date?
    private(set) var lastRecordingDuration: TimeInterval?

    override init() {
        self.volumeManager = MicrophoneVolumeManager.shared
        self.recorderFactory = { url, settings in try AVAudioRecorder(url: url, settings: settings) }
        self.dateProvider = { Date() }
        super.init()
        setupRecorder()
    }

    init(
        volumeManager: MicrophoneVolumeManaging = MicrophoneVolumeManager.shared,
        recorderFactory: @escaping (URL, [String: Any]) throws -> AVAudioRecorder,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.volumeManager = volumeManager
        self.recorderFactory = recorderFactory
        self.dateProvider = dateProvider
        super.init()
        setupRecorder()
    }
    
    private func setupRecorder() {
        // AVAudioSession is not needed on macOS
    }

    deinit {
        // Comprehensive cleanup when recorder is deallocated
        // 1. Stop recording if still active
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        // 2. Clear delegate to prevent callbacks to deallocated object
        audioRecorder?.delegate = nil
        audioRecorder = nil
        // 3. Invalidate timer to prevent callbacks
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        // 4. Clear recording URL reference
        recordingURL = nil
        // Note: @Published properties (isRecording, audioLevel) are automatically cleaned up
        // Note: Volume restoration should have been handled by stopRecording/cancelRecording
    }
    
    func startRecording() -> Bool {
        // Check permission via PermissionManager (single source of truth)
        guard PermissionManager.shared.microphonePermissionState == .granted else {
            return false
        }
        
        // Prevent re-entrancy - if already recording, return false
        guard audioRecorder == nil else {
            return false
        }
        
        // Boost microphone volume if enabled
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.boostMicrophoneVolume()
            }
        }
        
        let tempPath = FileManager.default.temporaryDirectory
        let timestamp = dateProvider().timeIntervalSince1970
        let audioFilename = tempPath.appendingPathComponent("recording_\(timestamp).m4a")
        
        recordingURL = audioFilename
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Note: On macOS, microphone selection is handled at the system level
        // The AVAudioRecorder will use the system's default input device
        // Users can change this in System Preferences > Sound > Input
        
        do {
            audioRecorder = try recorderFactory(audioFilename, settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            currentSessionStart = dateProvider()
            lastRecordingDuration = nil
            
            self.isRecording = true
            self.startLevelMonitoring()
            return true
        } catch {
            // Skip logging in tests to reduce console noise
            if !AppEnvironment.isRunningTests {
                Logger.audioRecorder.error("Failed to start recording: \(error.localizedDescription)")
            }
            // Restore volume if recording failed and we boosted it
            if UserDefaults.standard.autoBoostMicrophoneVolume {
                Task {
                    await volumeManager.restoreMicrophoneVolume()
                }
            }
            // Recheck permissions if recording failed
            PermissionManager.shared.checkPermissionState()
            return false
        }
    }
    
    func stopRecording() -> URL? {
        let now = dateProvider()
        let sessionDuration = currentSessionStart.map { now.timeIntervalSince($0) }
        lastRecordingDuration = sessionDuration
        currentSessionStart = nil

        audioRecorder?.stop()
        audioRecorder = nil
        
        // Restore microphone volume if it was boosted
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.restoreMicrophoneVolume()
            }
        }
        
        // Update @Published properties on main thread
        self.isRecording = false
        self.stopLevelMonitoring()
        
        return recordingURL
    }
    
    func cleanupRecording() {
        guard let url = recordingURL else { return }

        // Note: Volume restoration is handled by the caller (cancelRecording/stopRecording)
        // to avoid double restoration (bug fix)

        currentSessionStart = nil
        lastRecordingDuration = nil
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // Skip logging in tests to reduce console noise
            if !AppEnvironment.isRunningTests {
                Logger.audioRecorder.error("Failed to cleanup recording file: \(error.localizedDescription)")
            }
        }
        
        recordingURL = nil
    }
    
    func cancelRecording() {
        // Stop recording and cleanup without returning URL
        audioRecorder?.stop()
        audioRecorder = nil
        currentSessionStart = nil
        lastRecordingDuration = nil
        
        // Restore microphone volume if it was boosted
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.restoreMicrophoneVolume()
            }
        }
        
        // Update @Published properties on main thread
        self.isRecording = false
        self.stopLevelMonitoring()
        
        // Clean up the recording file
        cleanupRecording()
    }
    
    private func startLevelMonitoring() {
        // Use a more efficient approach for macOS
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder else { return }

                recorder.updateMeters()
                let normalizedLevel = self.normalizeLevel(recorder.averagePower(forChannel: 0))

                self.audioLevel = normalizedLevel
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelUpdateTimer?.invalidate()
        levelUpdateTimer = nil
        audioLevel = 0.0
    }
    
    private func normalizeLevel(_ level: Float) -> Float {
        // Convert dB to linear scale (0.0 to 1.0)
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        
        let clampedLevel = max(minDb, min(maxDb, level))
        return (clampedLevel - minDb) / (maxDb - minDb)
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.audioRecorder.error("Recording finished unsuccessfully")
        }
    }
}
