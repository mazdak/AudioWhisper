import Foundation
import AppKit

internal protocol SoundPlayable {
    @discardableResult
    func play() -> Bool
}

internal protocol SoundProviding {
    func sound(named name: String) -> SoundPlayable?
}

internal struct SystemSoundProvider: SoundProviding {
    func sound(named name: String) -> SoundPlayable? {
        NSSound(named: name)
    }
}

extension NSSound: SoundPlayable {}

@MainActor
internal class SoundManager: ObservableObject {
    private let soundProvider: SoundProviding
    
    init(soundProvider: SoundProviding = SystemSoundProvider()) {
        self.soundProvider = soundProvider
    }
    
    /// Plays a gentle completion sound when transcription finishes
    func playCompletionSound() {
        // Check user preference before playing sound
        let playSound = UserDefaults.standard.object(forKey: "playCompletionSound") as? Bool ?? true

        guard playSound else { return }

        // Use a gentle system sound that's pleasant and not jarring
        // This is the same sound used for successful operations in many Mac apps
        soundProvider.sound(named: "Glass")?.play()
    }

    /// Plays a quick sound when recording starts in express mode
    func playRecordingStartSound() {
        // Check user preference before playing sound (reuse completion sound setting)
        let playSound = UserDefaults.standard.object(forKey: "playCompletionSound") as? Bool ?? true

        guard playSound else { return }

        // Use a quick, subtle sound for recording start indication
        soundProvider.sound(named: "Ping")?.play()
    }
    
    /// Alternative completion sounds that can be used
    private enum CompletionSound: String, CaseIterable {
        case glass = "Glass"           // Gentle chime - recommended
        case tink = "Tink"            // Soft metallic sound
        case pop = "Pop"              // Gentle pop
        case purr = "Purr"            // Very soft sound
        
        var name: String {
            rawValue
        }
    }
    
    /// Test different completion sounds (for development/testing)
    func testCompletionSounds() {
        for soundType in CompletionSound.allCases {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(soundType.hashValue)) { [weak self] in
                self?.soundProvider.sound(named: soundType.name)?.play()
            }
        }
    }
}
