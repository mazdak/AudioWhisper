import SwiftUI

struct RecordingButton: View {
    let isRecording: Bool
    let hasPermission: Bool
    let isProcessing: Bool
    let showSuccess: Bool
    let transcriptionProvider: TranscriptionProvider
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: buttonIcon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(buttonColor)
                )
                .scaleEffect(showSuccess ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: showSuccess)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .disabled(isProcessing || !hasPermission || (showSuccess && !UserDefaults.standard.bool(forKey: "enableSmartPaste")))
        .help(transcriptionProvider.displayName)
        .onHover(perform: onHover)
    }
    
    private var buttonIcon: String {
        if showSuccess {
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            return enableSmartPaste ? "arrow.down.doc.on.clipboard" : "checkmark"
        } else if isRecording {
            return "stop.fill"
        } else if hasPermission {
            return "mic.fill"
        } else {
            return "mic.slash.fill"
        }
    }
    
    private var buttonColor: Color {
        if showSuccess {
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            return enableSmartPaste ? .green : .green  // Green for both paste and success
        } else if isRecording {
            return .red
        } else if hasPermission {
            return .blue
        } else {
            return .gray
        }
    }
    
    private var accessibilityLabel: String {
        if showSuccess {
            let enableSmartPaste = UserDefaults.standard.bool(forKey: "enableSmartPaste")
            return enableSmartPaste ? "Paste transcribed text" : "Transcription completed successfully"
        } else if isRecording {
            return "Stop recording"
        } else if !hasPermission {
            return "Microphone access required"
        } else if isProcessing {
            return "Processing audio"
        } else {
            return "Start recording"
        }
    }
    
    private var accessibilityHint: String {
        if showSuccess {
            return "Transcription is complete"
        } else if isRecording {
            return "Tap to stop recording audio"
        } else if !hasPermission {
            return "Grant microphone permission to record audio"
        } else if isProcessing {
            return "Please wait while audio is being processed"
        } else {
            return "Tap to start recording audio for transcription"
        }
    }
}