import XCTest
@testable import AudioWhisper

@MainActor
final class SoundManagerTests: XCTestCase {
    
    private var soundProvider: MockSoundProvider!
    private var soundManager: SoundManager!
    
    override func setUp() {
        super.setUp()
        soundProvider = MockSoundProvider()
        soundManager = SoundManager(soundProvider: soundProvider)
        UserDefaults.standard.removeObject(forKey: "playCompletionSound")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "playCompletionSound")
        soundManager = nil
        soundProvider = nil
        super.tearDown()
    }
    
    func testPlayCompletionSound_DefaultPreferencePlaysGlass() {
        soundManager.playCompletionSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Glass"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayCompletionSound_WhenDisabledDoesNotPlay() {
        UserDefaults.standard.set(false, forKey: "playCompletionSound")
        
        soundManager.playCompletionSound()
        
        XCTAssertTrue(soundProvider.requestedNames.isEmpty)
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 0)
    }
    
    func testPlayCompletionSound_WhenEnabledPlaysOnce() {
        UserDefaults.standard.set(true, forKey: "playCompletionSound")
        
        soundManager.playCompletionSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Glass"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayRecordingStartSound_UsesPingSound() {
        soundManager.playRecordingStartSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Ping"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayRecordingStartSound_WhenDisabledDoesNotPlay() {
        UserDefaults.standard.set(false, forKey: "playCompletionSound")
        
        soundManager.playRecordingStartSound()
        
        XCTAssertTrue(soundProvider.requestedNames.isEmpty)
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 0)
    }
}
