import AppKit
import AVFoundation
import Observation

internal enum PermissionState {
    case unknown
    case notRequested
    case requesting
    case granted
    case denied
    case restricted
    
    var needsRequest: Bool {
        switch self {
        case .unknown, .notRequested:
            return true
        default:
            return false
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .denied:
            return true
        default:
            return false
        }
    }
}

@MainActor
@Observable
internal class PermissionManager {
    static let shared = PermissionManager()

    var microphonePermissionState: PermissionState = .unknown
    var accessibilityPermissionState: PermissionState = .unknown
    var showEducationalModal = false
    var showRecoveryModal = false
    var showAccessibilityModal = false
    private let isTestEnvironment: Bool
    private let accessibilityManager = AccessibilityPermissionManager()
    
    var allPermissionsGranted: Bool {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        if enableSmartPaste {
            return microphonePermissionState == .granted && accessibilityPermissionState == .granted
        } else {
            return microphonePermissionState == .granted
        }
    }
    
    init() {
        // Detect if running in tests
        isTestEnvironment = AppEnvironment.isRunningTests
        // Load actual permission state on initialization
        checkPermissionState()
    }
    
    func checkPermissionState() {
        checkMicrophonePermission()
        // Always check accessibility permission for accurate status display
        checkAccessibilityPermission()
    }
    
    private func checkMicrophonePermission() {
        // Don't overwrite if we're already requesting permission
        guard microphonePermissionState != .requesting else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            self.microphonePermissionState = .granted
        case .denied:
            self.microphonePermissionState = .denied
        case .restricted:
            self.microphonePermissionState = .restricted
        case .notDetermined:
            self.microphonePermissionState = .notRequested
        @unknown default:
            self.microphonePermissionState = .unknown
        }
    }
    
    private func checkAccessibilityPermission() {
        // Use dedicated AccessibilityPermissionManager for consistent checking
        let trusted = accessibilityManager.checkPermission()

        self.accessibilityPermissionState = trusted ? .granted : .notRequested
    }
    
    func requestPermissionWithEducation() {
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        
        let needsMicrophone = microphonePermissionState.needsRequest
        let needsAccessibility = enableSmartPaste && accessibilityPermissionState.needsRequest
        
        let canRetryMicrophone = microphonePermissionState.canRetry
        let canRetryAccessibility = enableSmartPaste && accessibilityPermissionState.canRetry
        
        if needsMicrophone || needsAccessibility {
            showEducationalModal = true
        } else if canRetryMicrophone || canRetryAccessibility {
            showRecoveryModal = true
        }
    }
    
    func proceedWithPermissionRequest() {
        if isTestEnvironment {
            // In tests, simulate permission behavior without actual system dialog
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                // Simulate denied for consistent test behavior
                self.microphonePermissionState = .denied
                let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
                if enableSmartPaste {
                    self.accessibilityPermissionState = .denied
                }
                self.showRecoveryModal = true
            }
        } else {
            requestMicrophonePermission()

            // Show accessibility modal if SmartPaste is enabled and permission not granted
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            if enableSmartPaste && accessibilityPermissionState != .granted {
                // Delay slightly to let microphone dialog appear first
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    self.showAccessibilityModal = true
                }
            }
        }
    }

    /// Handle response from AccessibilityPermissionModal
    func handleAccessibilityModalResponse(allowed: Bool) {
        showAccessibilityModal = false

        if allowed {
            // User wants to grant permission - open System Settings
            accessibilityPermissionState = .requesting
            accessibilityManager.requestPermissionDirect { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.accessibilityPermissionState = granted ? .granted : .denied
                }
            }
        } else {
            // User chose "Don't Allow" - permanently disable SmartPaste
            UserDefaults.standard.set(false, forKey: "enableSmartPaste")
            // No longer need accessibility permission since SmartPaste is disabled
        }
    }
    
    private func requestMicrophonePermission() {
        if microphonePermissionState.needsRequest {
            microphonePermissionState = .requesting
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphonePermissionState = granted ? .granted : .denied
                    self?.checkIfAllPermissionsHandled()
                }
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        if accessibilityPermissionState.needsRequest {
            accessibilityPermissionState = .requesting
            
            // Use dedicated AccessibilityPermissionManager for proper explanation and handling
            accessibilityManager.requestPermissionWithExplanation { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.accessibilityPermissionState = granted ? .granted : .denied
                    self?.checkIfAllPermissionsHandled()
                }
            }
        }
    }
    
    private func checkIfAllPermissionsHandled() {
        let hasFailures = microphonePermissionState == .denied || accessibilityPermissionState == .denied
        if hasFailures && !showRecoveryModal {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.showRecoveryModal = true
            }
        }
    }
    
    func openSystemSettings() {
        // Skip actual system settings in test environment
        if isTestEnvironment {
            return
        }
        
        // Open the main Privacy & Security preferences
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
