import AppKit
import SwiftUI

class WelcomeWindow {
    static func showWelcomeDialog() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Welcome to AudioWhisper!"
        alert.informativeText = """
        AudioWhisper allows you to quickly record and transcribe audio using AI.
        
        To get started:
        • Configure your API key (OpenAI, Gemini, or use Local Whisper)
        • Use ⌘⇧Space to open the recording window
        • Press Space to start/stop recording
        • Transcribed text is automatically pasted
        
        Would you like to open Settings to configure your transcription provider?
        """
        alert.alertStyle = .informational
        
        // Set custom app icon instead of default folder icon
        if let appIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let appIcon = NSImage(contentsOfFile: appIconPath) {
            alert.icon = appIcon
        } else {
            // Fallback to system microphone icon if app icon not found
            let micIcon = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "AudioWhisper")
            micIcon?.isTemplate = false
            alert.icon = micIcon
        }
        
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Use Local Whisper")
        alert.addButton(withTitle: "Skip Setup")
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            return true // Open settings
        case .alertSecondButtonReturn:
            // Set local whisper as default
            UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
            return false // Don't open settings
        default:
            return false // Skip setup
        }
    }
}