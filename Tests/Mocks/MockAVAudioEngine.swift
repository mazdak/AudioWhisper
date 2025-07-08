import Foundation
import AVFoundation

class MockAVAudioEngine: AVAudioEngine {
    private var mockIsRunning = false
    
    override var isRunning: Bool {
        return mockIsRunning
    }
    
    override func prepare() {
        // Mock preparation
    }
    
    override func start() throws {
        mockIsRunning = true
    }
    
    override func stop() {
        mockIsRunning = false
    }
    
    func setMockRunningState(_ isRunning: Bool) {
        mockIsRunning = isRunning
    }
}