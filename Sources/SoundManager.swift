import Foundation
import AppKit

@MainActor
class SoundManager: ObservableObject {
    
    /// Plays a gentle completion sound when transcription finishes
    func playCompletionSound() {
        // Check user preference before playing sound
        let playSound = UserDefaults.standard.object(forKey: "playCompletionSound") as? Bool ?? true
        
        guard playSound else { return }
        
        // Use a gentle system sound that's pleasant and not jarring
        // This is the same sound used for successful operations in many Mac apps
        NSSound(named: "Glass")?.play()
    }
    
    /// Alternative completion sounds that can be used
    private enum CompletionSound: String, CaseIterable {
        case glass = "Glass"           // Gentle chime - recommended
        case tink = "Tink"            // Soft metallic sound
        case pop = "Pop"              // Gentle pop
        case purr = "Purr"            // Very soft sound
        
        var sound: NSSound? {
            return NSSound(named: self.rawValue)
        }
    }
    
    /// Test different completion sounds (for development/testing)
    func testCompletionSounds() {
        for soundType in CompletionSound.allCases {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(soundType.hashValue)) {
                soundType.sound?.play()
            }
        }
    }
}