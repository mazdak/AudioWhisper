import SwiftUI
import AVFoundation
import ApplicationServices

enum PermissionState {
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

class PermissionManager: ObservableObject {
    @Published var microphonePermissionState: PermissionState = .unknown
    @Published var accessibilityPermissionState: PermissionState = .unknown
    @Published var showEducationalModal = false
    @Published var showRecoveryModal = false
    private let isTestEnvironment: Bool
    
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
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
    }
    
    func checkPermissionState() {
        checkMicrophonePermission()
        
        // Only check Accessibility if SmartPaste is enabled
        let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
        if enableSmartPaste {
            checkAccessibilityPermission()
        } else {
            // Reset accessibility state if SmartPaste is disabled
            accessibilityPermissionState = .granted // Consider it "granted" since it's not needed
        }
    }
    
    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        DispatchQueue.main.async {
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
    }
    
    private func checkAccessibilityPermission() {
        // Check without prompting (like Maccy)
        let trusted = AXIsProcessTrustedWithOptions(nil)
        
        DispatchQueue.main.async {
            self.accessibilityPermissionState = trusted ? .granted : .notRequested
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            
            // Only request Accessibility if SmartPaste is enabled
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            if enableSmartPaste {
                requestAccessibilityPermission()
            }
        }
    }
    
    private func requestMicrophonePermission() {
        if microphonePermissionState.needsRequest {
            microphonePermissionState = .requesting
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermissionState = granted ? .granted : .denied
                    self?.checkIfAllPermissionsHandled()
                }
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        if accessibilityPermissionState.needsRequest {
            accessibilityPermissionState = .requesting
            
            // Request permission with prompt (like Maccy would)
            let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [checkOptionPrompt: true] as CFDictionary
            let _ = AXIsProcessTrustedWithOptions(options)
            
            // Check the result after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let trusted = AXIsProcessTrustedWithOptions(nil)
                self.accessibilityPermissionState = trusted ? .granted : .denied
                self.checkIfAllPermissionsHandled()
            }
        }
    }
    
    private func checkIfAllPermissionsHandled() {
        let hasFailures = microphonePermissionState == .denied || accessibilityPermissionState == .denied
        if hasFailures && !showRecoveryModal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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