import Foundation
import AppKit
import ApplicationServices

/// Dedicated manager for handling Accessibility permissions
internal class AccessibilityPermissionManager {
    private let isTestEnvironment: Bool
    private let permissionCheck: () -> Bool

    /// Tracks the current polling session to prevent parallel polling chains.
    /// When a new request comes in, we cancel any existing polling.
    private var currentPollingID: UUID?
    private let pollingLock = NSLock()

    init(permissionCheck: @escaping () -> Bool = { AXIsProcessTrustedWithOptions(nil) }) {
        isTestEnvironment = AppEnvironment.isRunningTests
        self.permissionCheck = permissionCheck
    }

    /// Checks if the app has Accessibility permission without prompting the user
    /// - Returns: true if permission is granted, false otherwise
    func checkPermission() -> Bool {
        return permissionCheck()
    }

    /// Requests permission directly without showing explanation alerts.
    /// Opens System Settings and monitors for permission grant.
    /// Cancels any existing polling before starting a new one.
    /// - Parameter completion: Called with the result of the permission request
    func requestPermissionDirect(completion: @escaping (Bool) -> Void) {
        // First check if already granted
        if checkPermission() {
            completion(true)
            return
        }

        // In tests, do not show any dialogs
        if isTestEnvironment {
            completion(false)
            return
        }

        // Open System Settings directly
        openAccessibilitySystemSettings()

        // Monitor permission status (cancels any existing polling)
        monitorPermissionStatus(completion: completion)
    }

    /// Legacy method for backwards compatibility - now just calls requestPermissionDirect
    func requestPermissionWithExplanation(completion: @escaping (Bool) -> Void) {
        requestPermissionDirect(completion: completion)
    }

    /// Cancels any ongoing permission polling
    func cancelPolling() {
        pollingLock.lock()
        currentPollingID = nil
        pollingLock.unlock()
    }

    /// Monitors permission status after opening System Settings.
    /// Automatically cancels any previous polling to prevent parallel chains.
    private func monitorPermissionStatus(completion: @escaping (Bool) -> Void) {
        if isTestEnvironment { completion(false); return }

        // Generate a new polling ID and cancel any existing polling
        let pollingID = UUID()
        pollingLock.lock()
        currentPollingID = pollingID
        pollingLock.unlock()

        var checkCount = 0
        let maxChecks = 60 // Check for up to 30 seconds (60 * 0.5s)

        func checkStatus() {
            // Check if this polling session was cancelled
            pollingLock.lock()
            let isCancelled = currentPollingID != pollingID
            pollingLock.unlock()

            if isCancelled {
                // Another request started - this polling chain should stop silently
                return
            }

            checkCount += 1

            if checkPermission() {
                completion(true)
                return
            }

            if checkCount >= maxChecks {
                // Timeout - permission not granted
                completion(false)
                return
            }

            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkStatus()
            }
        }

        // Start checking after initial delay to let System Settings open
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkStatus()
        }
    }

    /// Opens System Settings to the Accessibility section
    private func openAccessibilitySystemSettings() {
        if isTestEnvironment { return }
        // Try modern URL scheme first (macOS 13+)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        // Fallback to general Privacy & Security settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Shows an alert with instructions for manually enabling permission
    func showManualPermissionInstructions() {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Enable Accessibility Permission"
            alert.informativeText = """
            To enable SmartPaste functionality:

            1. Open System Settings (click "Open Settings" below)
            2. Go to Privacy & Security → Accessibility
            3. Find AudioWhisper in the list
            4. Toggle the switch to enable it
            5. Return to AudioWhisper

            If AudioWhisper isn't in the list, you may need to add it manually using the "+" button.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilitySystemSettings()
            }
        }
    }

    /// Returns a user-friendly status message for the current permission state
    var permissionStatusMessage: String {
        if checkPermission() {
            return "Accessibility permission granted - SmartPaste is enabled"
        } else {
            return "Accessibility permission required for SmartPaste functionality"
        }
    }

    /// Returns detailed status information for debugging and user support
    var detailedPermissionStatus: (isGranted: Bool, statusMessage: String, troubleshootingInfo: String?) {
        let isGranted = checkPermission()

        if isGranted {
            return (
                isGranted: true,
                statusMessage: "Accessibility permission is properly configured",
                troubleshootingInfo: nil
            )
        } else {
            return (
                isGranted: false,
                statusMessage: "Accessibility permission is not granted",
                troubleshootingInfo: """
                To enable SmartPaste:
                1. Open System Settings → Privacy & Security → Accessibility
                2. Add AudioWhisper to the list (using + button if needed)
                3. Toggle the switch to enable AudioWhisper
                4. Restart AudioWhisper if needed
                """
            )
        }
    }
}
