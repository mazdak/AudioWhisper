import Foundation
@testable import AudioWhisper

final class MockSound: SoundPlayable {
    private(set) var playCallCount = 0
    
    func play() -> Bool {
        playCallCount += 1
        return true
    }
}

final class MockSoundProvider: SoundProviding {
    private(set) var requestedNames: [String] = []
    var sounds: [String: MockSound] = [:]
    var defaultSound = MockSound()
    var shouldReturnNil = false
    
    func sound(named name: String) -> SoundPlayable? {
        requestedNames.append(name)
        guard !shouldReturnNil else { return nil }
        if let sound = sounds[name] {
            return sound
        }
        return defaultSound
    }
}
