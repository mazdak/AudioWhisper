import Foundation
import os.log

// Centralized logging for AudioWhisper
extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.audiowhisper.app"
    
    static let modelManager = Logger(subsystem: subsystem, category: "ModelManager")
    static let audioRecorder = Logger(subsystem: subsystem, category: "AudioRecorder")
    static let microphoneVolume = Logger(subsystem: subsystem, category: "MicrophoneVolume")
    static let speechToText = Logger(subsystem: subsystem, category: "SpeechToText")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    static let app = Logger(subsystem: subsystem, category: "App")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let dataManager = Logger(subsystem: subsystem, category: "DataManager")
}