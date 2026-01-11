import Foundation
import AppKit
import ApplicationServices
import Carbon
import Observation
import os.log

// MARK: - Keyboard Layout Helper

/// Modifier flags needed to type a character
private struct KeyModifiers: OptionSet {
    let rawValue: UInt8
    static let shift = KeyModifiers(rawValue: 1 << 0)
    static let option = KeyModifiers(rawValue: 1 << 1)
}

/// Helper to find the correct key code for a character based on the current keyboard layout.
/// This makes character-by-character typing work correctly with non-US layouts (e.g., Hungarian QWERTZ).
private final class KeyboardLayoutHelper {

    /// Cached mapping from character to (keyCode, modifiers) for current keyboard layout
    private var charToKeyCodeCache: [Character: (CGKeyCode, KeyModifiers)] = [:]
    private var cachedLayoutID: String?

    /// Shared instance
    static let shared = KeyboardLayoutHelper()

    private init() {
        rebuildCacheIfNeeded()
    }

    /// Find the key code and modifiers needed to type a character
    func keyCodeForCharacter(_ char: Character) -> (keyCode: CGKeyCode, modifiers: KeyModifiers)? {
        rebuildCacheIfNeeded()
        return charToKeyCodeCache[char]
    }

    /// Rebuild the cache if the keyboard layout has changed
    private func rebuildCacheIfNeeded() {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return
        }

        // Get layout identifier
        guard let layoutIDPtr = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) else {
            return
        }
        let layoutID = Unmanaged<CFString>.fromOpaque(layoutIDPtr).takeUnretainedValue() as String

        // Skip rebuild if layout hasn't changed
        if layoutID == cachedLayoutID && !charToKeyCodeCache.isEmpty {
            return
        }

        Logger.app.info("KeyboardLayoutHelper: Rebuilding cache for layout '\(layoutID)'")
        cachedLayoutID = layoutID
        charToKeyCodeCache.removeAll()

        // Get the keyboard layout data
        guard let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            Logger.app.warning("KeyboardLayoutHelper: Could not get layout data, falling back to US layout")
            return
        }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data

        layoutData.withUnsafeBytes { rawPtr in
            guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return
            }

            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var actualLength: Int = 0

            // Modifier combinations to scan (in priority order - prefer simpler modifiers)
            // Carbon modifier bits: shiftKey=0x200, optionKey=0x800
            // UCKeyTranslate expects these shifted right by 8
            let modifierCombinations: [(carbonMod: UInt32, keyMod: KeyModifiers)] = [
                (0, []),                                           // No modifiers
                (UInt32(shiftKey >> 8), .shift),                   // Shift only
                (UInt32(optionKey >> 8), .option),                 // Option only (AltGr)
                (UInt32((shiftKey | optionKey) >> 8), [.shift, .option])  // Shift+Option
            ]

            // Scan all key codes (0-127) with all modifier combinations
            for keyCode: UInt16 in 0..<128 {
                for (carbonMod, keyMod) in modifierCombinations {
                    deadKeyState = 0
                    let status = UCKeyTranslate(
                        ptr,
                        keyCode,
                        UInt16(kUCKeyActionDown),
                        carbonMod,
                        UInt32(LMGetKbdType()),
                        UInt32(kUCKeyTranslateNoDeadKeysBit),
                        &deadKeyState,
                        chars.count,
                        &actualLength,
                        &chars
                    )

                    if status == noErr && actualLength > 0 {
                        if let scalar = Unicode.Scalar(chars[0]) {
                            let char = Character(scalar)
                            // Only add if we don't already have a simpler way to type this character
                            if charToKeyCodeCache[char] == nil {
                                charToKeyCodeCache[char] = (CGKeyCode(keyCode), keyMod)
                            }
                        }
                    }
                }
            }
        }

        // Always add whitespace keys (these are layout-independent)
        charToKeyCodeCache[" "] = (CGKeyCode(kVK_Space), [])
        charToKeyCodeCache["\t"] = (CGKeyCode(kVK_Tab), [])
        charToKeyCodeCache["\n"] = (CGKeyCode(kVK_Return), [])
        charToKeyCodeCache["\r"] = (CGKeyCode(kVK_Return), [])

        Logger.app.info("KeyboardLayoutHelper: Cached \(self.charToKeyCodeCache.count) characters")

        // Log mappings for common problematic characters to help diagnose issues
        let debugChars: [Character] = ["'", "\"", "@", "#", "&", "[", "]", "{", "}", "|", "\\", "/", "?", "!"]
        for char in debugChars {
            if let (keyCode, mods) = charToKeyCodeCache[char] {
                var modStr = "none"
                if mods.contains(.shift) && mods.contains(.option) {
                    modStr = "shift+option"
                } else if mods.contains(.shift) {
                    modStr = "shift"
                } else if mods.contains(.option) {
                    modStr = "option"
                }
                Logger.app.debug("KeyboardLayoutHelper: '\(char)' -> keyCode=\(keyCode), mods=\(modStr)")
            } else {
                Logger.app.debug("KeyboardLayoutHelper: '\(char)' -> NOT FOUND")
            }
        }
    }
}

// Helper class to safely capture observer in closure
// Uses a lock to ensure thread-safe access to the mutable observer property
// @unchecked is required because we have mutable state but we ensure thread safety via NSLock
private final class ObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _observer: NSObjectProtocol?
    
    var observer: NSObjectProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _observer
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _observer = newValue
        }
    }
}

/// Errors that can occur during paste operations
internal enum PasteError: LocalizedError {
    case accessibilityPermissionDenied
    case eventSourceCreationFailed
    case keyboardEventCreationFailed
    case targetAppNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for SmartPaste. Please enable it in System Settings > Privacy & Security > Accessibility."
        case .eventSourceCreationFailed:
            return "Could not create event source for paste operation."
        case .keyboardEventCreationFailed:
            return "Could not create keyboard events for paste operation."
        case .targetAppNotAvailable:
            return "Target application is not available for pasting."
        }
    }
}

@Observable
@MainActor
internal class PasteManager {

    // MARK: - Timing Constants

    /// Delay between modifier registration and key press (for CGEvent paste)
    private static let modifierRegisterDelay: UInt32 = 50_000     // 50ms
    /// Delay between keyDown and keyUp (for CGEvent paste)
    private static let keyUpDelay: UInt32 = 20_000                // 20ms
    /// Delay between characters when typing directly (slower for RustDesk network capture)
    private static let interCharacterDelay: UInt32 = 30_000       // 30ms
    /// Delay between key down and up for direct typing
    private static let directTypeKeyDelay: UInt32 = 15_000        // 15ms

    private let accessibilityManager: AccessibilityPermissionManager

    /// UserDefaults key for SmartPaste excluded apps - shared with preferences UI
    internal static let smartPasteExcludedAppsKey = "smartPasteExcludedApps"

    /// Key to track if migration has been performed
    private static let exclusionMigrationKey = "smartPasteExclusionMigrationV1"

    /// Default apps to exclude on first launch (migration from hardcoded values)
    private static let defaultExcludedApps = [
        "com.carriez.rustdesk",      // RustDesk - Cmd+V doesn't work due to CGEventSourceKeyState issue
        "com.rustdesk.RustDesk",     // Alternative bundle ID
    ]

    /// Cached set of excluded bundle IDs - invalidated when UserDefaults changes
    private static var _cachedExcludedBundleIDs: Set<String>?
    private static var _userDefaultsObserver: NSObjectProtocol?

    /// Apps where SmartPaste doesn't work well and should be skipped
    /// (text remains in clipboard for manual paste)
    /// Users can manage this list in Preferences -> Smart Paste -> Excluded Apps
    private static var smartPasteExcludedBundleIDs: Set<String> {
        if let cached = _cachedExcludedBundleIDs {
            return cached
        }

        // Migration: seed defaults on first launch for users upgrading from hardcoded exclusions
        if !UserDefaults.standard.bool(forKey: exclusionMigrationKey) {
            // Only seed if the key doesn't exist yet (fresh install or upgrade)
            if UserDefaults.standard.object(forKey: smartPasteExcludedAppsKey) == nil {
                UserDefaults.standard.set(defaultExcludedApps, forKey: smartPasteExcludedAppsKey)
            }
            UserDefaults.standard.set(true, forKey: exclusionMigrationKey)
        }

        let ids = Set(UserDefaults.standard.stringArray(forKey: smartPasteExcludedAppsKey) ?? [])
        _cachedExcludedBundleIDs = ids

        // Observe UserDefaults changes to invalidate cache
        if _userDefaultsObserver == nil {
            _userDefaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                _cachedExcludedBundleIDs = nil
            }
        }
        return ids
    }

    init(accessibilityManager: AccessibilityPermissionManager = AccessibilityPermissionManager()) {
        self.accessibilityManager = accessibilityManager
    }

    /// Check if the current frontmost app should be excluded from SmartPaste
    private func shouldSkipSmartPaste() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            return false
        }

        if Self.smartPasteExcludedBundleIDs.contains(bundleID) {
            Logger.app.info("PasteManager: Skipping SmartPaste for excluded app: \(bundleID)")
            return true
        }
        return false
    }

    /// Attempts to paste text to the currently active application
    /// Uses CGEvent to simulate ⌘V
    func pasteToActiveApp() {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")

        if enableSmartPaste {
            // Skip SmartPaste for excluded apps (like RustDesk)
            if shouldSkipSmartPaste() {
                Logger.app.info("PasteManager: Text copied to clipboard (SmartPaste skipped for this app)")
                return
            }
            // Use CGEvent to simulate ⌘V
            performCGEventPaste()
        } else {
            // Just copy to clipboard - user will manually paste
            // Text is already in clipboard from transcription
        }
    }
    
    /// SmartPaste function that attempts to paste text into a specific application
    /// This is the function mentioned in the test requirements
    func smartPaste(into targetApp: NSRunningApplication?, text: String) {
        // First copy text to clipboard as fallback - this ensures users always have access to the text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        
        guard enableSmartPaste else {
            // SmartPaste is disabled in settings - fail with appropriate error
            handlePasteResult(.failure(PasteError.targetAppNotAvailable))
            return
        }

        // Skip SmartPaste for excluded apps (like RustDesk) - text is already in clipboard
        if let bundleID = targetApp?.bundleIdentifier,
           Self.smartPasteExcludedBundleIDs.contains(bundleID) {
            Logger.app.info("PasteManager: SmartPaste skipped for excluded app: \(bundleID). Text in clipboard.")
            handlePasteResult(.success(()))  // Report success since text is in clipboard
            return
        }

        // CRITICAL: Check accessibility permission without prompting - never bypass this check
        // If this fails, we must NOT attempt to proceed with CGEvent operations
        guard accessibilityManager.checkPermission() else {
            // Permission is definitively denied - show proper error and stop processing
            // Do NOT attempt any paste operations without permission
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            return
        }
        
        // Validate target application
        guard let targetApp = targetApp, !targetApp.isTerminated else {
            handlePasteResult(.failure(PasteError.targetAppNotAvailable))
            return
        }
        
        // Attempt to activate target application
        let activationSuccess = targetApp.activate(options: [])
        if !activationSuccess {
            // App activation failed - this could indicate the app is not responsive
            handlePasteResult(.failure(PasteError.targetAppNotAvailable))
            return
        }
        
        // Wait for app to become active before pasting
        waitForApplicationActivation(targetApp) { [weak self] in
            guard let self = self else { return }
            
            // Double-check permission before performing paste (belt and suspenders approach)
            guard self.accessibilityManager.checkPermission() else {
                // Permission was revoked between initial check and paste attempt
                self.handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
                return
            }
            
            self.performCGEventPaste()
        }
    }
    
    /// Performs paste with completion handler for proper coordination
    @MainActor
    func pasteWithCompletionHandler() async {
        await withCheckedContinuation { continuation in
            pasteWithUserInteraction { _ in
                continuation.resume()
            }
        }
    }
    
    /// Performs paste with immediate user interaction context
    /// This should work better than automatic pasting
    func pasteWithUserInteraction(completion: ((Result<Void, PasteError>) -> Void)? = nil) {
        // Check permission first - if denied, show proper explanation and request
        guard accessibilityManager.checkPermission() else {
            // Show permission request with explanation - this includes user education
            accessibilityManager.requestPermissionWithExplanation { [weak self] granted in
                guard let self = self else { return }
                
                if granted {
                    // Permission was granted - attempt paste operation
                    self.performCGEventPaste(completion: completion)
                } else {
                    // User declined permission - show appropriate message and fail gracefully
                    self.accessibilityManager.showPermissionDeniedMessage()
                    self.handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
                    completion?(.failure(PasteError.accessibilityPermissionDenied))
                }
            }
            return
        }
        
        // Permission is available - proceed with paste
        performCGEventPaste(completion: completion)
    }
    
    // MARK: - CGEvent Paste
    
    private func performCGEventPaste(completion: ((Result<Void, PasteError>) -> Void)? = nil) {
        // CRITICAL: Prevent any paste operations during tests
        if NSClassFromString("XCTestCase") != nil {
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            completion?(.failure(PasteError.accessibilityPermissionDenied))
            return
        }

        // Skip SmartPaste for excluded apps (like RustDesk) - text stays in clipboard
        if shouldSkipSmartPaste() {
            Logger.app.info("PasteManager: Text in clipboard (SmartPaste skipped for this app)")
            handlePasteResult(.success(()))
            completion?(.success(()))
            return
        }

        // CRITICAL SECURITY CHECK: Always verify accessibility permission before any CGEvent operations
        // This method should NEVER execute without proper permission - no exceptions
        guard accessibilityManager.checkPermission() else {
            // Permission is not granted - STOP IMMEDIATELY and report error
            // We must never attempt CGEvent operations without permission
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            completion?(.failure(PasteError.accessibilityPermissionDenied))
            return
        }
        
        // Permission is verified - proceed with paste operation
        do {
            try simulateCmdVPaste()
            // Paste operation completed successfully
            handlePasteResult(.success(()))
            completion?(.success(()))
        } catch let error as PasteError {
            // Handle known paste errors
            handlePasteResult(.failure(error))
            completion?(.failure(error))
        } catch {
            // Handle unexpected errors during paste operation
            handlePasteResult(.failure(PasteError.keyboardEventCreationFailed))
            completion?(.failure(PasteError.keyboardEventCreationFailed))
        }
    }
    
    // Removed - using AccessibilityPermissionManager instead
    
    /// Main paste simulation function.
    ///
    /// ## Direct Typing Mode (for Remote Desktop apps like RustDesk)
    /// When `useDirectTypingForPaste` is enabled, types text character-by-character.
    /// This bypasses Cmd+V entirely because RustDesk's `CGEventSourceKeyState` only sees
    /// physical keyboard state, making synthetic modifier keys invisible.
    /// Uses layout-aware key code detection for correct typing on any keyboard layout.
    /// **Note**: Blocks main thread during typing (~45ms per character).
    ///
    /// ## Normal Mode
    /// 1. **AppleScript**: `keystroke "v" using command down` - works well with most apps.
    /// 2. **CGEvent**: FlagsChanged + key events at HID level.
    /// 3. **Character typing**: Fallback if other methods fail.
    private func simulateCmdVPaste() throws {
        // CRITICAL: Prevent any paste operations during tests
        if NSClassFromString("XCTestCase") != nil {
            throw PasteError.accessibilityPermissionDenied
        }

        // Final permission check before creating any CGEvents
        // This is our last line of defense against unauthorized paste operations
        guard accessibilityManager.checkPermission() else {
            Logger.app.error("PasteManager: Accessibility permission denied")
            throw PasteError.accessibilityPermissionDenied
        }

        Logger.app.info("PasteManager: Starting paste operation")

        // Check if user prefers typing directly (for remote desktop apps like RustDesk)
        // This mode types character-by-character because Cmd+V cannot work with RustDesk.
        // See Research/rustdesk_paste_attempts.md for full explanation.
        let useDirectTyping = UserDefaults.standard.bool(forKey: "useDirectTypingForPaste")
        if useDirectTyping {
            Logger.app.info("PasteManager: Direct Typing Mode - typing character-by-character")
            if !typeClipboardContents() {
                throw PasteError.keyboardEventCreationFailed
            }
            return
        }

        // Try AppleScript approach first - this works better with some apps
        if tryAppleScriptPaste() {
            Logger.app.info("PasteManager: AppleScript paste succeeded")
            return
        }

        Logger.app.info("PasteManager: AppleScript failed, trying CGEvent approach")

        // Try CGEvent approach
        do {
            try simulateCGEventPaste()
            return
        } catch {
            Logger.app.warning("PasteManager: CGEvent paste failed: \(error)")
        }

        // Final fallback: type the text directly (works with remote desktop apps)
        Logger.app.info("PasteManager: All paste methods failed, falling back to direct typing")
        if !typeClipboardContents() {
            throw PasteError.keyboardEventCreationFailed
        }
    }

    /// Get clipboard contents and type them directly
    /// - Returns: true if text was typed, false if clipboard was empty
    @discardableResult
    private func typeClipboardContents() -> Bool {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            Logger.app.error("PasteManager: No text in clipboard")
            return false
        }
        typeTextDirectly(text)
        return true
    }

    /// Try pasting using AppleScript - works better with some apps like RustDesk
    private func tryAppleScriptPaste() -> Bool {
        let script = """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                Logger.app.warning("PasteManager: AppleScript error: \(error)")
                return false
            }
            return true
        }
        return false
    }

    /// Simulate Cmd+V using CGEvent with flagsChanged events for modifiers
    private func simulateCGEventPaste() throws {
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            Logger.app.error("PasteManager: Failed to create event source")
            throw PasteError.eventSourceCreationFailed
        }

        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        let cmdFlag = CGEventFlags([.maskCommand])
        let noFlag = CGEventFlags([])

        Logger.app.info("PasteManager: Creating flagsChanged + key events")

        // Create flagsChanged event for Command key down (this is what the system generates for modifier presses)
        guard let flagsChangedDown = CGEvent(source: source) else {
            Logger.app.error("PasteManager: Failed to create flagsChanged event")
            throw PasteError.keyboardEventCreationFailed
        }
        flagsChangedDown.type = .flagsChanged
        flagsChangedDown.flags = cmdFlag

        // Create V key events
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            Logger.app.error("PasteManager: Failed to create keyboard events")
            throw PasteError.keyboardEventCreationFailed
        }

        // Set Command flag on V key events
        keyVDown.flags = cmdFlag
        keyVUp.flags = cmdFlag

        // Create flagsChanged event for Command key up
        guard let flagsChangedUp = CGEvent(source: source) else {
            Logger.app.error("PasteManager: Failed to create flagsChanged up event")
            throw PasteError.keyboardEventCreationFailed
        }
        flagsChangedUp.type = .flagsChanged
        flagsChangedUp.flags = noFlag

        // Post the sequence using HID tap (lowest level)
        let tap: CGEventTapLocation = .cghidEventTap
        Logger.app.info("PasteManager: Posting flagsChanged sequence to HID tap")

        // Send: flagsChanged(cmd down) -> keyDown(v) -> keyUp(v) -> flagsChanged(cmd up)
        flagsChangedDown.post(tap: tap)
        usleep(Self.modifierRegisterDelay)
        keyVDown.post(tap: tap)
        usleep(Self.keyUpDelay)
        keyVUp.post(tap: tap)
        usleep(Self.modifierRegisterDelay)
        flagsChangedUp.post(tap: tap)

        Logger.app.info("PasteManager: CGEvent paste completed")
    }

    /// Type text character by character - fallback for apps that don't handle Cmd+V well.
    /// Uses layout-aware key code detection for correct typing on any keyboard layout.
    private func typeTextDirectly(_ text: String) {
        Logger.app.info("PasteManager: Typing text directly (\(text.count) characters)")

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            Logger.app.error("PasteManager: Failed to create event source for typing")
            return
        }

        let layoutHelper = KeyboardLayoutHelper.shared

        for char in text {
            // Try layout-aware lookup first (works with any keyboard layout)
            if let (keyCode, modifiers) = layoutHelper.keyCodeForCharacter(char) {
                // Build CGEventFlags from KeyModifiers
                var flags = CGEventFlags([])
                if modifiers.contains(.shift) {
                    flags.insert(.maskShift)
                }
                if modifiers.contains(.option) {
                    flags.insert(.maskAlternate)
                }

                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                   let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                    keyDown.flags = flags
                    keyUp.flags = flags

                    keyDown.post(tap: .cghidEventTap)
                    usleep(Self.directTypeKeyDelay)
                    keyUp.post(tap: .cghidEventTap)
                }
            } else {
                // Fallback: use unicode string for unmapped characters (e.g., accented chars not on current layout)
                // This works for local apps but may not work with RustDesk for special characters
                let uniChars = Array(String(char).utf16)
                let neutralKeyCode = CGKeyCode(0x72)  // kVK_Help - doesn't produce visible chars

                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: neutralKeyCode, keyDown: true) {
                    keyDown.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
                    keyDown.post(tap: .cghidEventTap)
                    usleep(Self.directTypeKeyDelay)
                }
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: neutralKeyCode, keyDown: false) {
                    keyUp.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
                    keyUp.post(tap: .cghidEventTap)
                }
                Logger.app.debug("PasteManager: Using unicode fallback for character not on current layout: '\(char)'")
            }

            // Small delay between characters
            usleep(Self.interCharacterDelay)
        }

        Logger.app.info("PasteManager: Finished typing text")
    }
    
    private func handlePasteResult(_ result: Result<Void, PasteError>) {
        let (name, object): (Notification.Name, Any?) = {
            switch result {
            case .success: return (.pasteOperationSucceeded, nil)
            case .failure(let error): return (.pasteOperationFailed, error.localizedDescription)
            }
        }()
        NotificationCenter.default.post(name: name, object: object)
    }
    
    @available(*, deprecated, message: "Use handlePasteResult instead")
    private func handlePasteFailure(reason: String) {
        handlePasteResult(.failure(PasteError.keyboardEventCreationFailed))
    }
    
    // MARK: - App Activation Handling
    
    private func waitForApplicationActivation(_ target: NSRunningApplication, completion: @escaping () -> Void) {
        // If already active, execute completion immediately
        if target.isActive {
            completion()
            return
        }
        
        let observerBox = ObserverBox()
        var timeoutCancelled = false
        
        // Set up timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak observerBox] in
            guard !timeoutCancelled else { return }
            if let observer = observerBox?.observer {
                NotificationCenter.default.removeObserver(observer)
            }
            // Execute completion even on timeout to avoid hanging
            completion()
        }
        
        // Observe app activation
        observerBox.observer = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak observerBox] notification in
            if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               activatedApp.processIdentifier == target.processIdentifier {
                timeoutCancelled = true
                if let observer = observerBox?.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                completion()
            }
        }
    }
    
}
