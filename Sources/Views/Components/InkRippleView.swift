import SwiftUI

/// A single ripple that expands outward and fades
private struct Ripple: Identifiable {
    let id = UUID()
    let startTime: Date
    let intensity: CGFloat // 0-1, affects size and opacity
}

/// Ink Ripples visualization that responds to audio level
internal struct InkRippleView: View {
    let audioLevel: Float
    let isActive: Bool
    
    @State private var ripples: [Ripple] = []
    @State private var lastRippleTime: Date = .distantPast
    
    // Terracotta color from theme
    private let inkColor = Color(red: 0.76, green: 0.42, blue: 0.32)
    
    // Ripple timing
    private let minRippleInterval: TimeInterval = 0.15
    private let rippleLifetime: TimeInterval = 1.2
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) / 2
            
            ZStack {
                // Base ink pool - subtle center dot
                Circle()
                    .fill(inkColor.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .position(center)
                
                // Ripples
                ForEach(ripples) { ripple in
                    RippleCircle(
                        ripple: ripple,
                        center: center,
                        maxRadius: maxRadius,
                        lifetime: rippleLifetime,
                        inkColor: inkColor
                    )
                }
                
                // Center pool that pulses with audio
                Circle()
                    .fill(inkColor.opacity(0.4 + Double(audioLevel) * 0.3))
                    .frame(width: 8 + CGFloat(audioLevel) * 8, height: 8 + CGFloat(audioLevel) * 8)
                    .position(center)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)
            }
        }
        .onChange(of: audioLevel) { _, newLevel in
            guard isActive else { return }
            maybeSpawnRipple(level: newLevel)
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            cleanupOldRipples()
        }
        .onAppear {
            ripples = []
        }
        .onChange(of: isActive) { _, active in
            if !active {
                // Let existing ripples fade out naturally
            }
        }
    }
    
    private func maybeSpawnRipple(level: Float) {
        let now = Date()
        let timeSinceLastRipple = now.timeIntervalSince(lastRippleTime)
        
        // Spawn ripples based on audio level and time
        // Higher level = more frequent ripples
        let threshold = max(0.1, 0.3 - Double(level) * 0.2)
        
        if timeSinceLastRipple > threshold && level > 0.05 {
            let ripple = Ripple(startTime: now, intensity: CGFloat(min(1, level * 1.5)))
            ripples.append(ripple)
            lastRippleTime = now
        }
    }
    
    private func cleanupOldRipples() {
        let now = Date()
        ripples.removeAll { now.timeIntervalSince($0.startTime) > rippleLifetime }
    }
}

/// Individual ripple circle with animation
private struct RippleCircle: View {
    let ripple: Ripple
    let center: CGPoint
    let maxRadius: CGFloat
    let lifetime: TimeInterval
    let inkColor: Color
    
    @State private var progress: CGFloat = 0
    
    var body: some View {
        let currentRadius = maxRadius * progress * ripple.intensity
        let opacity = (1 - progress) * Double(ripple.intensity) * 0.6
        
        Circle()
            .stroke(inkColor.opacity(opacity), lineWidth: 2 - progress * 1.5)
            .frame(width: currentRadius * 2, height: currentRadius * 2)
            .position(center)
            .onAppear {
                withAnimation(.easeOut(duration: lifetime)) {
                    progress = 1
                }
            }
    }
}

/// Recording view with ink ripples - the main container
internal struct InkRippleRecordingView: View {
    let status: AppStatus
    let audioLevel: Float
    let onTap: () -> Void
    
    private let creamBg = Color(red: 0.98, green: 0.96, blue: 0.93)
    private let inkColor = Color(red: 0.76, green: 0.42, blue: 0.32)
    private let textColor = Color(red: 0.12, green: 0.11, blue: 0.10)
    private let mutedColor = Color(red: 0.55, green: 0.52, blue: 0.48)
    
    var body: some View {
        VStack(spacing: 0) {
            // Ripple area
            ZStack {
                // Cream background
                RoundedRectangle(cornerRadius: 16)
                    .fill(creamBg)
                
                // Ink ripples
                InkRippleView(
                    audioLevel: audioLevel,
                    isActive: isRecording
                )
                .padding(20)
                
                // Center tap target
                Button(action: onTap) {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(inkColor.opacity(0.3), lineWidth: 1)
                            .frame(width: 56, height: 56)
                        
                        // Inner filled circle
                        Circle()
                            .fill(buttonFill)
                            .frame(width: 48, height: 48)
                        
                        // Icon
                        Image(systemName: buttonIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(buttonIconColor)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: 200, height: 140)
            
            // Status text
            HStack(spacing: 6) {
                if status.shouldAnimate {
                    Circle()
                        .fill(inkColor)
                        .frame(width: 6, height: 6)
                        .opacity(pulsingOpacity)
                }
                
                Text(statusText)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(textColor)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(creamBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.85, green: 0.82, blue: 0.78), lineWidth: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }
    
    private var isProcessing: Bool {
        if case .processing = status { return true }
        return false
    }
    
    private var isSuccess: Bool {
        if case .success = status { return true }
        return false
    }
    
    private var statusText: String {
        switch status {
        case .recording:
            return "Listening..."
        case .processing(let message):
            return message
        case .success:
            return "Done"
        case .ready:
            return "Tap to record"
        case .permissionRequired:
            return "Permission needed"
        case .error(let message):
            return message
        }
    }
    
    private var buttonIcon: String {
        switch status {
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .ready, .permissionRequired:
            return "mic.fill"
        case .error:
            return "exclamationmark"
        }
    }
    
    private var buttonFill: Color {
        switch status {
        case .recording:
            return inkColor
        case .processing:
            return mutedColor.opacity(0.3)
        case .success:
            return Color(red: 0.35, green: 0.55, blue: 0.40)
        case .ready:
            return inkColor.opacity(0.15)
        case .permissionRequired, .error:
            return mutedColor.opacity(0.2)
        }
    }
    
    private var buttonIconColor: Color {
        switch status {
        case .recording, .success:
            return .white
        case .processing:
            return mutedColor
        case .ready:
            return inkColor
        case .permissionRequired, .error:
            return mutedColor
        }
    }
    
    @State private var pulsingOpacity: Double = 1.0
    
    private var pulsingAnimation: Animation {
        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }
}

// MARK: - Preview
#Preview("Ink Ripple - Recording") {
    InkRippleRecordingView(
        status: .recording,
        audioLevel: 0.5,
        onTap: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Ink Ripple - Ready") {
    InkRippleRecordingView(
        status: .ready,
        audioLevel: 0,
        onTap: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
