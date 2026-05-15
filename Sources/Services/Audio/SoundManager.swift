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
        guard AppDefaults.playCompletionSound else { return }

        // Use a gentle system sound that's pleasant and not jarring
        // This is the same sound used for successful operations in many Mac apps
        soundProvider.sound(named: "Glass")?.play()
    }

    /// Plays a quick sound when recording starts in express mode
    func playRecordingStartSound() {
        // Check user preference before playing sound (reuse completion sound setting)
        guard AppDefaults.playCompletionSound else { return }

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
    /// Plays each sound with a 1-second interval between them
    func testCompletionSounds() {
        for (index, soundType) in CompletionSound.allCases.enumerated() {
            // Use deterministic index-based timing (1 second between each sound)
            let delay = Double(index)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.soundProvider.sound(named: soundType.name)?.play()
            }
        }
    }
}
