import SwiftUI

struct PermissionEducationModal: View {
    let onProceed: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .accessibilityLabel("Microphone permission required")
            
            VStack(spacing: 12) {
                Text("Microphone Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("AudioWhisper needs access to your microphone to record audio for transcription.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Record high-quality audio", systemImage: "waveform.circle.fill")
                    Label("Process everything locally or in the cloud", systemImage: "cloud.circle.fill")
                    Label("Your audio is never stored permanently", systemImage: "lock.circle.fill")
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                Button("Not Now") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Dismiss this dialog without granting microphone permission")
                
                Button("Allow Microphone Access") {
                    onProceed()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Grant microphone permission to start recording audio")
            }
        }
        .padding(24)
        .frame(width: 400)
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
                .accessibilityLabel("Warning: Microphone access denied")
            
            VStack(spacing: 12) {
                Text("Microphone Access Denied")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("To use AudioWhisper, you'll need to enable microphone access in System Settings.")
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
                        Text("Find AudioWhisper in the microphone list")
                    }
                    
                    HStack {
                        Text("3.")
                            .fontWeight(.semibold)
                        Text("Toggle the switch to enable access")
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
                .accessibilityHint("Open macOS System Settings to enable microphone access")
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}