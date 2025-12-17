import Foundation
import AppKit
import ApplicationServices
import Carbon
import Observation

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
    
    private let accessibilityManager: AccessibilityPermissionManager
    
    init(accessibilityManager: AccessibilityPermissionManager = AccessibilityPermissionManager()) {
        self.accessibilityManager = accessibilityManager
    }
    
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
