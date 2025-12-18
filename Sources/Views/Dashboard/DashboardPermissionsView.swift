import SwiftUI
import AVFoundation
import ApplicationServices
import AppKit

internal struct DashboardPermissionsView: View {
    @State private var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    @AppStorage("enableSmartPaste") private var enableSmartPaste = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xl) {
                pageHeader
                microphoneSection
                
                if enableSmartPaste {
                    accessibilitySection
                }
            }
            .padding(DashboardTheme.Spacing.xl)
        }
        .background(DashboardTheme.pageBg)
        .onAppear(perform: refreshStatuses)
        .onChange(of: enableSmartPaste) { _, _ in
            refreshStatuses()
        }
    }
    
    // MARK: - Header
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
            Text("Permissions")
                .font(DashboardTheme.Fonts.serif(28, weight: .semibold))
                .foregroundStyle(DashboardTheme.ink)
            
            Text("System permissions required for recording and smart paste")
                .font(DashboardTheme.Fonts.sans(13, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
        }
    }
    
    // MARK: - Microphone
    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Microphone")
            
            VStack(alignment: .leading, spacing: 0) {
                permissionStatusRow(
                    status: microphoneStatus == .authorized ? .granted : .required,
                    title: microphoneStatusTitle,
                    description: "Required to capture audio for transcription"
                )
                
                Divider()
                    .background(DashboardTheme.rule)
                
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Button("Request Access") {
                        requestMicrophonePermission()
                    }
                    .buttonStyle(PaperAccentButtonStyle())
                    .disabled(microphoneStatus == .authorized)
                    
                    Button("Open Settings") {
                        openSystemSettings(path: "Privacy_Microphone")
                    }
                    .buttonStyle(PaperButtonStyle())
                }
                .padding(DashboardTheme.Spacing.md)
            }
            .cardStyle()
        }
    }
    
    // MARK: - Accessibility
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            sectionHeader("Accessibility")
            
            VStack(alignment: .leading, spacing: 0) {
                permissionStatusRow(
                    status: isAccessibilityTrusted ? .granted : .required,
                    title: isAccessibilityTrusted ? "Access granted" : "Permission required",
                    description: "Required for Smart Paste to type transcribed text"
                )
                
                Divider()
                    .background(DashboardTheme.rule)
                
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Button("Open Settings") {
                        openSystemSettings(path: "Privacy_Accessibility")
                    }
                    .buttonStyle(PaperAccentButtonStyle())
                    
                    Button("Refresh") {
                        refreshStatuses()
                    }
                    .buttonStyle(PaperButtonStyle())
                }
                .padding(DashboardTheme.Spacing.md)
            }
            .cardStyle()
        }
    }
    
    // MARK: - Helpers
    private enum PermissionStatus {
        case granted, required
        
        var icon: String {
            switch self {
            case .granted: return "checkmark.circle"
            case .required: return "exclamationmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .granted: return DashboardTheme.success
            case .required: return DashboardTheme.accent
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
            .foregroundStyle(DashboardTheme.inkMuted)
            .tracking(0.8)
            .textCase(.uppercase)
    }
    
    private func permissionStatusRow(
        status: PermissionStatus,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .center, spacing: DashboardTheme.Spacing.md) {
            Image(systemName: status.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(status.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: DashboardTheme.Spacing.xs) {
                Text(title)
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text(description)
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
        }
        .padding(DashboardTheme.Spacing.md)
    }
    
    private var microphoneStatusTitle: String {
        switch microphoneStatus {
        case .authorized:
            return "Access granted"
        case .denied:
            return "Permission denied"
        case .restricted:
            return "Access restricted"
        case .notDetermined:
            return "Not yet requested"
        @unknown default:
            return "Unknown status"
        }
    }
    
    // MARK: - Actions
    private func refreshStatuses() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        isAccessibilityTrusted = AXIsProcessTrusted()
    }
    
    private func requestMicrophonePermission() {
        guard !AppEnvironment.isRunningTests else { return }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                microphoneStatus = granted ? .authorized : .denied
            }
        }
    }
    
    private func openSystemSettings(path: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(path)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Card Style
private extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(DashboardTheme.cardBg)
                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
    }
}
