import Foundation
import AVFoundation
import Combine
import os.log

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var hasPermission = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelUpdateTimer: Timer?
    private let volumeManager = MicrophoneVolumeManager.shared
    private(set) var currentSessionStart: Date?
    private(set) var lastRecordingDuration: TimeInterval?
    
    override init() {
        super.init()
        setupRecorder()
        checkMicrophonePermission()
    }
    
    private func setupRecorder() {
        // AVAudioSession is not needed on macOS
    }
    
    func checkMicrophonePermission() {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch permissionStatus {
        case .authorized:
            DispatchQueue.main.async {
                self.hasPermission = true
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                }
            }
        @unknown default:
            DispatchQueue.main.async {
                self.hasPermission = false
            }
        }
    }
    
    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }
    
    func startRecording() -> Bool {
        // Check permission first
        guard hasPermission else {
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
        let audioFilename = tempPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
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
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            currentSessionStart = Date()
            lastRecordingDuration = nil
            
            // Update @Published properties on main thread
            if Thread.isMainThread {
                self.isRecording = true
                self.startLevelMonitoring()
            } else {
                DispatchQueue.main.sync {
                    self.isRecording = true
                    self.startLevelMonitoring()
                }
            }
            return true
        } catch {
            Logger.audioRecorder.error("Failed to start recording: \(error.localizedDescription)")
            // Restore volume if recording failed and we boosted it
            if UserDefaults.standard.autoBoostMicrophoneVolume {
                Task {
                    await volumeManager.restoreMicrophoneVolume()
                }
            }
            // Recheck permissions if recording failed
            checkMicrophonePermission()
            return false
        }
    }
    
    func stopRecording() -> URL? {
        let sessionDuration = currentSessionStart.map { Date().timeIntervalSince($0) }
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
        if Thread.isMainThread {
            self.isRecording = false
            self.stopLevelMonitoring()
        } else {
            DispatchQueue.main.sync {
                self.isRecording = false
                self.stopLevelMonitoring()
            }
        }
        
        return recordingURL
    }
    
    func cleanupRecording() {
        guard let url = recordingURL else { return }
        
        // Restore microphone volume if it was boosted (in case of cancellation/cleanup)
        if UserDefaults.standard.autoBoostMicrophoneVolume {
            Task {
                await volumeManager.restoreMicrophoneVolume()
            }
        }

        currentSessionStart = nil
        lastRecordingDuration = nil
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Logger.audioRecorder.error("Failed to cleanup recording file: \(error.localizedDescription)")
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
        if Thread.isMainThread {
            self.isRecording = false
            self.stopLevelMonitoring()
        } else {
            DispatchQueue.main.sync {
                self.isRecording = false
                self.stopLevelMonitoring()
            }
        }
        
        // Clean up the recording file
        cleanupRecording()
    }
    
    private func startLevelMonitoring() {
        // Use a more efficient approach for macOS
        levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let normalizedLevel = self.normalizeLevel(recorder.averagePower(forChannel: 0))
            
            // Update on main thread if needed
            if Thread.isMainThread {
                self.audioLevel = normalizedLevel
            } else {
                DispatchQueue.main.async {
                    self.audioLevel = normalizedLevel
                }
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
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Logger.audioRecorder.error("Recording finished unsuccessfully")
        }
    }
}
