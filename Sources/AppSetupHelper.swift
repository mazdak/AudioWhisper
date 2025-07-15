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
        let iconSize = getAdaptiveMenuBarIconSize()
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
        let image = NSImage(systemSymbolName: "microphone.circle", accessibilityDescription: LocalizedStrings.Accessibility.microphoneIcon)?.withSymbolConfiguration(config)
        image?.isTemplate = true // This makes it adapt to menu bar appearance
        return image ?? NSImage()
    }
    
    // MARK: - Menu Bar Icon Constants
    private static let STANDARD_MENU_BAR_HEIGHT: CGFloat = 24.0
    private static let NOTCHED_MENU_BAR_THRESHOLD: CGFloat = 26.0
    private static let STANDARD_ICON_SIZE: CGFloat = 16.0  // For regular displays
    private static let NOTCHED_ICON_SIZE: CGFloat = 20.0   // For notched displays (taller menu bar)
    
    // Display detection constants
    private static let NOTCHED_ASPECT_RATIO_MIN: CGFloat = 1.5
    private static let NOTCHED_ASPECT_RATIO_MAX: CGFloat = 1.6
    private static let NOTCHED_MIN_HEIGHT: CGFloat = 1900.0
    
    // Cache for icon size to avoid repeated calculations
    private static var _cachedIconSize: CGFloat?
    private static var _lastMainScreenFrame: NSRect?
    
    /// Reset the cached icon size - useful when display configuration changes
    static func resetIconSizeCache() {
        _cachedIconSize = nil
        _lastMainScreenFrame = nil
    }
    
    static func getAdaptiveMenuBarIconSize() -> CGFloat {
        // Check for user override first
        if let overrideSize = UserDefaults.standard.object(forKey: "menuBarIconSize") as? Double,
           overrideSize > 0 {
            return CGFloat(overrideSize)
        }
        
        // For menu bar items, we should use the screen where the status item is located
        // not necessarily the main screen
        guard let statusItemScreen = getStatusItemScreen() else {
            // Fallback to standard size if we can't detect the screen
            return STANDARD_ICON_SIZE
        }
        
        // Check if screen configuration has changed by comparing frame
        let currentFrame = statusItemScreen.frame
        
        if let cached = _cachedIconSize, 
           let lastFrame = _lastMainScreenFrame,
           NSEqualRects(lastFrame, currentFrame) {
            return cached
        }
        
        // Detect if display has notch (taller menu bar) on the correct screen
        let hasNotch = detectDisplayNotchForScreen(statusItemScreen)
        
        // Adaptive sizing based on menu bar height
        let iconSize: CGFloat = hasNotch ? NOTCHED_ICON_SIZE : STANDARD_ICON_SIZE
        
        // Cache the result
        _cachedIconSize = iconSize
        _lastMainScreenFrame = currentFrame
        
        return iconSize
    }
    
    private static func getStatusItemScreen() -> NSScreen? {
        // Try to get the screen where the menu bar is displayed
        // In most cases, this is the screen with menu bar
        for screen in NSScreen.screens {
            // The screen with the menu bar typically has y origin at 0
            if screen.frame.origin.y == 0 {
                return screen
            }
        }
        // Fallback to main screen
        return NSScreen.main
    }
    
    private static func detectDisplayNotch() -> Bool {
        guard let mainScreen = NSScreen.main else {
            return false  // Default to no notch if screen detection fails
        }
        return detectDisplayNotchForScreen(mainScreen)
    }
    
    private static func detectDisplayNotchForScreen(_ screen: NSScreen) -> Bool {
        // Check safe area insets (macOS 12+) - most reliable method
        // Notched displays have safe area insets at the top for the notch
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0
        }
        
        // For older macOS versions, assume no notch
        return false
    }
    
    
    static func checkFirstRun() -> Bool {
        let hasExistingProvider = UserDefaults.standard.string(forKey: "transcriptionProvider") != nil
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        let lastWelcomeVersion = UserDefaults.standard.string(forKey: "lastWelcomeVersion") ?? "0"
        
        // Current version that includes SmartPaste feature
        let currentWelcomeVersion = "1.1" // Update this when SmartPaste feature is released
        
        // Show welcome for new users OR existing users who haven't seen the SmartPaste welcome
        let shouldShowWelcome = (!hasExistingProvider && !hasCompletedWelcome) || (lastWelcomeVersion != currentWelcomeVersion)
        
        if shouldShowWelcome {
            if !hasExistingProvider {
                // First run - default to LocalWhisper
                UserDefaults.standard.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
            }
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