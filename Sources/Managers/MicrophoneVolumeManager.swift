import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import os.log
import Observation

@Observable
internal class MicrophoneVolumeManager {
    static let shared = MicrophoneVolumeManager()
    
    private var originalVolume: Float32?
    private var audioDeviceID: AudioDeviceID?
    private var isVolumeBoosted = false
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Temporarily boost microphone volume to maximum (100%)
    func boostMicrophoneVolume() async -> Bool {
        guard !isVolumeBoosted else { return true }
        
        do {
            let deviceID = try await getDefaultInputDevice()
            let currentVolume = try await getInputVolume(deviceID: deviceID)
            
            // Store original volume and device for restoration
            originalVolume = currentVolume
            audioDeviceID = deviceID
            
            // Set volume to maximum
            let success = try await setInputVolume(deviceID: deviceID, volume: 1.0)
            if success {
                isVolumeBoosted = true
            }
            
            return success
        } catch {
            Logger.microphoneVolume.error("Failed to boost microphone volume: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Restore microphone volume to its original level
    func restoreMicrophoneVolume() async {
        guard isVolumeBoosted,
              let originalVolume = originalVolume,
              let deviceID = audioDeviceID else {
            return
        }
        
        do {
            _ = try await setInputVolume(deviceID: deviceID, volume: originalVolume)
        } catch {
            Logger.microphoneVolume.error("Failed to restore microphone volume: \(error.localizedDescription)")
        }
        
        // Clean up state regardless of success
        self.originalVolume = nil
        self.audioDeviceID = nil
        isVolumeBoosted = false
    }
    
    /// Check if microphone volume control is available
    func isVolumeControlAvailable() async -> Bool {
        do {
            let deviceID = try await getDefaultInputDevice()
            return try await hasVolumeControl(deviceID: deviceID)
        } catch {
            return false
        }
    }
    
    // MARK: - Core Audio Implementation
    
    private func getDefaultInputDevice() async throws -> AudioDeviceID {
        return try await withCheckedThrowingContinuation { continuation in
            var deviceID: AudioDeviceID = 0
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &size,
                &deviceID
            )
            
            if status == noErr {
                continuation.resume(returning: deviceID)
            } else {
                continuation.resume(throwing: VolumeError.deviceNotFound)
            }
        }
    }
    
    private func hasVolumeControl(deviceID: AudioDeviceID) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let hasProperty = AudioObjectHasProperty(deviceID, &address)
            continuation.resume(returning: hasProperty)
        }
    }
    
    private func getInputVolume(deviceID: AudioDeviceID) async throws -> Float32 {
        return try await withCheckedThrowingContinuation { continuation in
            var volume: Float32 = 0.0
            var size = UInt32(MemoryLayout<Float32>.size)
            
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &size,
                &volume
            )
            
            if status == noErr {
                continuation.resume(returning: volume)
            } else {
                continuation.resume(throwing: VolumeError.getVolumeFailed)
            }
        }
    }
    
    private func setInputVolume(deviceID: AudioDeviceID, volume: Float32) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            var newVolume = volume
            let size = UInt32(MemoryLayout<Float32>.size)
            
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectSetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                size,
                &newVolume
            )
            
            if status == noErr {
                continuation.resume(returning: true)
            } else if status == kAudioHardwareUnsupportedOperationError {
                // Some devices don't support volume control
                continuation.resume(returning: false)
            } else {
                continuation.resume(throwing: VolumeError.setVolumeFailed)
            }
        }
    }
    
    // MARK: - Alternative Implementation for USB/External Microphones
    
    /// Alternative method using AVCaptureDevice for external microphones
    private func boostAVCaptureDeviceVolume() -> Bool {
        _ = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        
        guard AVCaptureDevice.default(for: .audio) != nil else {
            return false
        }
        
        // Note: AVCaptureDevice doesn't provide direct volume control
        // This would require using AVAudioSession on iOS, but on macOS
        // we need to use Core Audio as implemented above
        
        return false
    }
}

// MARK: - Error Types

internal enum VolumeError: LocalizedError {
    case deviceNotFound
    case getVolumeFailed
    case setVolumeFailed
    case volumeControlNotSupported
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Default input device not found"
        case .getVolumeFailed:
            return "Failed to get current volume"
        case .setVolumeFailed:
            return "Failed to set volume"
        case .volumeControlNotSupported:
            return "Volume control not supported for this device"
        }
    }
}

// MARK: - Extension for UserDefaults Key

internal extension UserDefaults {
    var autoBoostMicrophoneVolume: Bool {
        get { bool(forKey: "autoBoostMicrophoneVolume") }
        set { set(newValue, forKey: "autoBoostMicrophoneVolume") }
    }
}
