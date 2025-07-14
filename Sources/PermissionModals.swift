import SwiftUI

struct PermissionEducationModal: View {
    let onProceed: () -> Void
    let onCancel: () -> Void
    
    private var enableSmartPaste: Bool {
        UserDefaults.standard.bool(forKey: "enableSmartPaste")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                if enableSmartPaste {
                    Image(systemName: "accessibility.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)
                }
            }
            .accessibilityLabel("Permissions required")
            
            VStack(spacing: 12) {
                Text(enableSmartPaste ? "Permissions Required" : "Microphone Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(enableSmartPaste ? 
                     "AudioWhisper needs permissions to work properly:" :
                     "AudioWhisper needs microphone access to record audio:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Microphone access to record audio", systemImage: "mic.circle.fill")
                        .foregroundColor(.blue)
                    if enableSmartPaste {
                        Label("Accessibility access to paste transcribed text", systemImage: "accessibility.circle.fill")
                            .foregroundColor(.green)
                    }
                    Label("Your audio is never stored permanently", systemImage: "lock.circle.fill")
                        .foregroundColor(.secondary)
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button("Not Now") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss this dialog without granting permissions")
                
                Button(enableSmartPaste ? "Allow Permissions" : "Allow Microphone Access") {
                    onProceed()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(enableSmartPaste ? "Grant microphone and accessibility permissions" : "Grant microphone permission")
            }
        }
        .padding(24)
        .frame(width: enableSmartPaste ? 420 : 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

struct PermissionRecoveryModal: View {
    let onOpenSettings: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .accessibilityLabel("Warning: Permissions denied")
            
            VStack(spacing: 12) {
                Text("Permissions Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("AudioWhisper needs microphone and accessibility permissions to work properly.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("1.")
                            .fontWeight(.semibold)
                        Text("Click 'Open System Settings' below")
                    }
                    
                    HStack {
                        Text("2.")
                            .fontWeight(.semibold)
                        Text("Enable AudioWhisper in 'Microphone' section")
                    }
                    
                    HStack {
                        Text("3.")
                            .fontWeight(.semibold)
                        Text("Enable AudioWhisper in 'Accessibility' section")
                    }
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss this dialog without opening System Settings")
                
                Button("Open System Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Open macOS System Settings to enable permissions")
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}