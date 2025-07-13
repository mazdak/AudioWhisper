import Foundation
import ServiceManagement
import AppKit
import os.log

class AppSetupHelper {
    static func setupApp() {
        // Only set activation policy if NSApp is available (not in unit tests)
        if Thread.isMainThread && NSApplication.shared.delegate != nil {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        setupLoginItem()
        cleanupOldTemporaryFiles()
    }
    
    static func setupLoginItem() {
        let startAtLogin = UserDefaults.standard.object(forKey: "startAtLogin") as? Bool ?? true // Default to true
        
        if startAtLogin {
            // Only try to register if we're in a real app context, not in tests
            if Bundle.main.bundleIdentifier != nil && !isRunningInTests() {
                try? SMAppService.mainApp.register()
            }
        }
    }
    
    private static func isRunningInTests() -> Bool {
        return NSClassFromString("XCTestCase") != nil
    }
    
    static func createMenuBarIcon() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: LocalizedStrings.Accessibility.microphoneIcon)?.withSymbolConfiguration(config)
        image?.isTemplate = true // This makes it adapt to menu bar appearance
        return image ?? NSImage()
    }
    
    static func checkFirstRun() -> Bool {
        let hasExistingProvider = UserDefaults.standard.string(forKey: "transcriptionProvider") != nil
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        
        if !hasExistingProvider && !hasCompletedWelcome {
            // First run - default to LocalWhisper
            UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
            return true
        } else if !hasExistingProvider {
            // Provider was somehow reset - default to LocalWhisper
            UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        }
        
        return false
    }
    
    static func cleanupOldTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])
            let audioFiles = files.filter { $0.lastPathComponent.hasPrefix("recording_") && $0.pathExtension == "m4a" }
            
            let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
            
            for file in audioFiles {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date, creationDate < cutoffDate {
                        try FileManager.default.removeItem(at: file)
                    }
                } catch {
                    Logger.app.error("Failed to clean up file \(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
        } catch {
            Logger.app.error("Failed to clean up temporary files: \(error.localizedDescription)")
        }
    }
}