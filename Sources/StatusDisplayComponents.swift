import SwiftUI

struct StatusDisplayView: View {
    let status: AppStatus
    let audioLevel: Float
    let onPermissionInfoTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatusIndicator(status: status)
                StatusMessage(status: status)
                
                if status.showInfoButton {
                    Button(action: onPermissionInfoTapped) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Get help with microphone permissions")
                }
            }
            
            // Audio level indicator
            if case .recording = status {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(audioLevel), height: 4)
                            .animation(.easeOut(duration: 0.05), value: audioLevel)
                    }
                }
                .frame(height: 4)
                .accessibilityLabel("Audio level: \(Int(audioLevel * 100)) percent")
            }
        }
    }
}

struct StatusIndicator: View {
    let status: AppStatus
    @State private var isAnimating = false
    
    var body: some View {
        // Fixed size container to prevent any positional animation
        ZStack {
            Color.clear
                .frame(width: 12, height: 12) // Fixed container size
            
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .opacity(status.shouldAnimate ? (isAnimating ? 0.7 : 1.0) : 1.0)
                .onAppear {
                    if status.shouldAnimate {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                }
                .onChange(of: status.shouldAnimate) { _, shouldAnimate in
                    if shouldAnimate {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isAnimating = false
                        }
                    }
                }
        }
    }
}

struct StatusMessage: View {
    let status: AppStatus
    
    var body: some View {
        Text(status.message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(status == .permissionRequired ? .secondary : .primary)
            .accessibilityLabel(accessibilityMessage)
    }
    
    private var accessibilityMessage: String {
        switch status {
        case .error(let message):
            return "Error: \(message)"
        case .recording:
            return "Currently recording audio"
        case .processing(let message):
            return "Processing: \(message)"
        case .success:
            return "Transcription completed successfully"
        case .ready:
            return "Ready to record"
        case .permissionRequired:
            return "Microphone permission required to record audio"
        }
    }
}