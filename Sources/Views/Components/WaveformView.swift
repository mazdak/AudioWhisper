import SwiftUI

/// Audio waveform visualization - minimal dark aesthetic
internal struct WaveformRecordingView: View {
    let status: AppStatus
    let audioLevel: Float
    let onTap: () -> Void
    
    // Dark void background
    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.04)
    // Soft cream/white for bars
    private let barColor = Color(red: 0.85, green: 0.83, blue: 0.80)
    // Muted for inactive states
    private let mutedColor = Color(red: 0.35, green: 0.34, blue: 0.33)
    // Success green
    private let successColor = Color(red: 0.45, green: 0.75, blue: 0.55)
    // Error/recording accent
    private let accentColor = Color(red: 0.85, green: 0.45, blue: 0.40)
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Waveform area
                ZStack {
                    bgColor
                    
                    WaveformBars(
                        audioLevel: audioLevel,
                        isActive: isRecording,
                        barColor: currentBarColor
                    )
                    .padding(.horizontal, 24)
                }
                .frame(height: 120)
                
                // Status bar
                HStack(spacing: 8) {
                    // Status indicator dot
                    if shouldShowDot {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)
                            .modifier(PulseModifier(isActive: isRecording || isProcessing))
                    }
                    
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .tracking(0.5)
                        .foregroundStyle(mutedColor)
                }
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(bgColor)
            }
        }
        .buttonStyle(.plain)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - State
    
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
    
    private var isError: Bool {
        if case .error = status { return true }
        return false
    }
    
    private var shouldShowDot: Bool {
        switch status {
        case .recording, .processing, .success, .error:
            return true
        default:
            return false
        }
    }
    
    private var dotColor: Color {
        switch status {
        case .recording:
            return accentColor
        case .processing:
            return barColor
        case .success:
            return successColor
        case .error:
            return accentColor
        default:
            return mutedColor
        }
    }
    
    private var currentBarColor: Color {
        switch status {
        case .recording:
            return barColor
        case .processing:
            return mutedColor
        case .success:
            return successColor
        case .error:
            return accentColor
        default:
            return mutedColor.opacity(0.5)
        }
    }
    
    private var statusText: String {
        switch status {
        case .recording:
            return "LISTENING"
        case .processing(let message):
            return message.uppercased()
        case .success:
            return "COPIED"
        case .ready:
            return "TAP TO RECORD"
        case .permissionRequired:
            return "PERMISSION NEEDED"
        case .error(let message):
            return message.uppercased()
        }
    }
}

// MARK: - Waveform Bars

private struct WaveformBars: View {
    let audioLevel: Float
    let isActive: Bool
    let barColor: Color
    
    private let barCount = 48
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 2
    private let minHeight: CGFloat = 2
    private let maxHeight: CGFloat = 60
    
    @State private var animatedLevels: [CGFloat] = []
    @State private var idlePhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .onAppear {
            animatedLevels = Array(repeating: minHeight, count: barCount)
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateLevels()
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard index < animatedLevels.count else { return minHeight }
        return animatedLevels[index]
    }
    
    private func updateLevels() {
        idlePhase += 0.08
        
        var newLevels: [CGFloat] = []
        let centerIndex = barCount / 2
        
        for i in 0..<barCount {
            let distanceFromCenter = abs(i - centerIndex)
            let normalizedDistance = CGFloat(distanceFromCenter) / CGFloat(centerIndex)
            
            // Base wave shape - higher in center, tapering to edges
            let baseShape = 1.0 - pow(normalizedDistance, 1.5)
            
            if isActive && audioLevel > 0.01 {
                // Active recording - respond to audio
                let level = CGFloat(audioLevel)
                
                // Add some randomness for organic feel
                let noise = CGFloat.random(in: -0.15...0.15)
                let variation = sin(CGFloat(i) * 0.5 + idlePhase * 2) * 0.2
                
                let height = minHeight + (maxHeight - minHeight) * baseShape * level * (1 + noise + variation)
                newLevels.append(max(minHeight, min(maxHeight, height)))
            } else {
                // Idle state - subtle breathing wave
                let breathe = sin(idlePhase + CGFloat(i) * 0.15) * 0.5 + 0.5
                let idleHeight = minHeight + (maxHeight * 0.08) * baseShape * breathe
                newLevels.append(idleHeight)
            }
        }
        
        // Smooth transition
        withAnimation(.linear(duration: 0.05)) {
            animatedLevels = newLevels
        }
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? (isPulsing ? 0.4 : 1.0) : 1.0)
            .onAppear {
                if isActive {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}

// MARK: - Previews

#Preview("Waveform - Recording") {
    WaveformRecordingView(
        status: .recording,
        audioLevel: 0.6,
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}

#Preview("Waveform - Ready") {
    WaveformRecordingView(
        status: .ready,
        audioLevel: 0,
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}

#Preview("Waveform - Processing") {
    WaveformRecordingView(
        status: .processing("Transcribing..."),
        audioLevel: 0,
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}

#Preview("Waveform - Success") {
    WaveformRecordingView(
        status: .success,
        audioLevel: 0,
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}
