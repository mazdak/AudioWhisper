import Foundation
import AppKit
import ApplicationServices
import Carbon
import Observation
import os.log

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

// Helper class to safely capture cancellation state (bug fix)
// Avoids capture-by-value issue where timeoutCancelled var was captured by value
// Marked @unchecked Sendable with lock for thread-safe cross-isolation access
private final class CancelledFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false

    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

/// Thread-safe flag to ensure continuation is resumed exactly once.
/// Used to prevent double-resume when timeout and completion race.
internal final class ResumedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _resumed = false

    /// Attempts to resume. Returns true if this is the first call, false otherwise.
    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _resumed { return false }
        _resumed = true
        return true
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

    private let accessibilityManager: AccessibilityPermissionManager

    init(accessibilityManager: AccessibilityPermissionManager = AccessibilityPermissionManager()) {
        self.accessibilityManager = accessibilityManager
    }

    // MARK: - Clipboard Operations

    /// Copies text to the system clipboard.
    /// This is the centralized method for all clipboard write operations.
    /// - Parameter text: The text to copy to the clipboard.
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Reads text from the system clipboard.
    /// - Returns: The text from the clipboard, or nil if no text is available.
    static func readFromClipboard() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    /// Clears the system clipboard contents.
    static func clearClipboard() {
        NSPasteboard.general.clearContents()
    }

    // MARK: - Paste Operations

    /// Attempts to paste text to the currently active application
    /// Uses CGEvent to simulate ⌘V
    func pasteToActiveApp() {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        
        if enableSmartPaste {
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
    
    /// Performs paste with completion handler for proper coordination.
    /// Includes a timeout to prevent indefinite hangs if the completion is never called.
    @MainActor
    func pasteWithCompletionHandler() async {
        Logger.paste.debug("pasteWithCompletionHandler called")

        // Use a thread-safe flag to ensure continuation is resumed exactly once
        let resumedFlag = ResumedFlag()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Set up a timeout to prevent indefinite hangs
            // The paste operation should complete almost instantly, so 2 seconds is generous
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(2))
                if resumedFlag.tryResume() {
                    Logger.paste.warning("pasteWithCompletionHandler: timed out waiting for paste completion")
                    continuation.resume()
                }
            }

            pasteWithUserInteraction { result in
                timeoutTask.cancel()
                switch result {
                case .success:
                    Logger.paste.debug("pasteWithCompletionHandler: paste succeeded")
                case .failure(let error):
                    Logger.paste.error("pasteWithCompletionHandler: paste failed: \(error.localizedDescription, privacy: .public)")
                }
                if resumedFlag.tryResume() {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Performs paste with immediate user interaction context
    /// This should work better than automatic pasting
    func pasteWithUserInteraction(completion: ((Result<Void, PasteError>) -> Void)? = nil) {
        Logger.paste.debug("pasteWithUserInteraction called")
        // Check permission first - if denied, fail gracefully
        // Text is already in clipboard so user can paste manually
        // Don't open System Settings here - it's disruptive and loses focus
        let hasPermission = accessibilityManager.checkPermission()
        Logger.paste.debug("pasteWithUserInteraction: accessibility permission = \(hasPermission)")
        guard hasPermission else {
            Logger.paste.warning("pasteWithUserInteraction: accessibility permission denied")
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            completion?(.failure(PasteError.accessibilityPermissionDenied))
            return
        }

        // Permission is available - proceed with paste
        Logger.paste.debug("pasteWithUserInteraction: calling performCGEventPaste")
        performCGEventPaste(completion: completion)
    }
    
    // MARK: - CGEvent Paste
    
    private func performCGEventPaste(completion: ((Result<Void, PasteError>) -> Void)? = nil) {
        Logger.paste.debug("performCGEventPaste called")
        // CRITICAL: Prevent any paste operations during tests
        if NSClassFromString("XCTestCase") != nil {
            Logger.paste.debug("performCGEventPaste: skipping in test environment")
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            completion?(.failure(PasteError.accessibilityPermissionDenied))
            return
        }

        // CRITICAL SECURITY CHECK: Always verify accessibility permission before any CGEvent operations
        // This method should NEVER execute without proper permission - no exceptions
        guard accessibilityManager.checkPermission() else {
            // Permission is not granted - STOP IMMEDIATELY and report error
            // We must never attempt CGEvent operations without permission
            Logger.paste.warning("performCGEventPaste: accessibility permission check failed")
            handlePasteResult(.failure(PasteError.accessibilityPermissionDenied))
            completion?(.failure(PasteError.accessibilityPermissionDenied))
            return
        }

        // Permission is verified - proceed with paste operation
        Logger.paste.debug("performCGEventPaste: calling simulateCmdVPaste")
        do {
            try simulateCmdVPaste()
            // Paste operation completed successfully
            Logger.paste.debug("performCGEventPaste: simulateCmdVPaste succeeded")
            handlePasteResult(.success(()))
            completion?(.success(()))
        } catch let error as PasteError {
            // Handle known paste errors
            Logger.paste.error("performCGEventPaste: PasteError: \(error.localizedDescription, privacy: .public)")
            handlePasteResult(.failure(error))
            completion?(.failure(error))
        } catch {
            // Handle unexpected errors during paste operation
            Logger.paste.error("performCGEventPaste: unexpected error: \(error.localizedDescription, privacy: .public)")
            handlePasteResult(.failure(PasteError.keyboardEventCreationFailed))
            completion?(.failure(PasteError.keyboardEventCreationFailed))
        }
    }
    
    // Removed - using AccessibilityPermissionManager instead
    
    private func simulateCmdVPaste() throws {
        // CRITICAL: Prevent any paste operations during tests
        if NSClassFromString("XCTestCase") != nil {
            throw PasteError.accessibilityPermissionDenied
        }
        
        // Final permission check before creating any CGEvents
        // This is our last line of defense against unauthorized paste operations
        guard accessibilityManager.checkPermission() else {
            throw PasteError.accessibilityPermissionDenied
        }
        
        // Create event source with proper session state
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw PasteError.eventSourceCreationFailed
        }
        
        // Configure event source to suppress local events during paste operation
        // This prevents interference from local keyboard input
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        
        // Create ⌘V key events for paste operation
        let cmdFlag = CGEventFlags([.maskCommand])
        let vKeyCode = CGKeyCode(kVK_ANSI_V) // V key code
        
        // Create both key down and key up events for complete key press simulation
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            throw PasteError.keyboardEventCreationFailed
        }
        
        // Apply Command modifier flag to both events
        keyVDown.flags = cmdFlag
        keyVUp.flags = cmdFlag
        
        // Post the key events to the system
        // This simulates pressing and releasing ⌘V
        keyVDown.post(tap: .cgSessionEventTap)
        keyVUp.post(tap: .cgSessionEventTap)
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

    // MARK: - App Activation Handling
    
    private func waitForApplicationActivation(_ target: NSRunningApplication, completion: @escaping () -> Void) {
        // If already active, execute completion immediately
        if target.isActive {
            completion()
            return
        }

        let observerBox = ObserverBox()
        let cancelledFlag = CancelledFlag()  // Use reference type to share state across closures

        // Set up timeout
        // Capture observerBox strongly so it survives until timeout/activation
        // The observerBox is only deallocated after the observer is properly removed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [observerBox, cancelledFlag] in
            guard !cancelledFlag.value else { return }
            if let observer = observerBox.observer {
                NotificationCenter.default.removeObserver(observer)
                observerBox.observer = nil  // Clear reference to allow cleanup
            }
            // Execute completion even on timeout to avoid hanging
            completion()
        }

        // Observe app activation
        // Capture observerBox strongly to ensure we can remove the observer
        observerBox.observer = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [observerBox, cancelledFlag] notification in
            if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               activatedApp.processIdentifier == target.processIdentifier {
                cancelledFlag.value = true
                if let observer = observerBox.observer {
                    NotificationCenter.default.removeObserver(observer)
                    observerBox.observer = nil  // Clear reference to allow cleanup
                }
                completion()
            }
        }
    }
    
}
