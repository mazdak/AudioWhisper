import SwiftUI

/// Container view that switches between waveform visualization styles.
/// Reads the style preference from UserDefaults and displays the appropriate visualization.
struct WaveformContainer: View {
    let status: AppStatus
    let audioLevel: Float
    let waveformSamples: [Float]
    let frequencyBands: [Float]
    /// When false, animations inside the `.processing` indicator are
    /// suppressed so snapshot tests render a deterministic frame.
    /// Production callers should leave this at the default (`true`).
    let processingAnimated: Bool
    let onTap: () -> Void

    init(
        status: AppStatus,
        audioLevel: Float,
        waveformSamples: [Float],
        frequencyBands: [Float],
        processingAnimated: Bool = true,
        onTap: @escaping () -> Void
    ) {
        self.status = status
        self.audioLevel = audioLevel
        self.waveformSamples = waveformSamples
        self.frequencyBands = frequencyBands
        self.processingAnimated = processingAnimated
        self.onTap = onTap
    }

    @AppDefault(\.waveformStyle) private var waveformStyle
    @AppDefault(\.visualIntensity) private var visualIntensity

    // Track previous status for transitions
    @State private var previousStatus: AppStatus?
    @State private var showError = false

    // Colors (sourced from WaveformPalette so the theme owns the literals)
    private let bgColor = WaveformPalette.background
    private let barColor = WaveformPalette.bar
    private let mutedColor = WaveformPalette.muted
    private let successColor = WaveformPalette.success
    private let accentColor = WaveformPalette.accent

    private var style: WaveformStyle { waveformStyle }

    private var intensity: VisualIntensity { visualIntensity }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glass background (expressive and bold only)
                if intensity.showGlass {
                    GlassBackground(intensity: intensity, cornerRadius: 12)
                }

                // Solid background (with reduced opacity if glass is active)
                bgColor.opacity(intensity.showGlass ? 0.7 : 1.0)

                // Waveform fills entire container edge-to-edge
                waveformView

                // Particle overlay for neon style (scaled by intensity)
                if style == .neon && isRecording {
                    ParticleOverlay(audioLevel: audioLevel, isActive: true)
                        .opacity(intensity.particleMultiplier)
                }

                // State transition effects. While processing, the wave
                // animation is non-deterministic (driven by wall-clock
                // time); allow tests to suppress it via processingAnimated.
                if processingAnimated || !isProcessing {
                    StatusTransitionOverlay(
                        fromStatus: previousStatus,
                        toStatus: status,
                        intensity: intensity
                    )
                }

                // Success celebration
                if isSuccess {
                    SuccessCelebration(
                        intensity: intensity,
                        isActive: true,
                        successColor: successColor
                    )
                }

                // Status text overlay at bottom
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        if shouldShowDot {
                            EnhancedStatusDot(
                                color: dotColor,
                                intensity: intensity,
                                isPulsing: shouldPulseStatusDot
                            )
                        }

                        Text(statusText)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .tracking(0.5)
                            .foregroundStyle(statusTextColor)
                    }
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                    .padding(.bottom, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shake(when: showError, intensity: intensity)
        .onChange(of: status) { oldStatus, newStatus in
            previousStatus = oldStatus
            // Trigger shake on error
            if case .error = newStatus {
                showError = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showError = false
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording waveform")
        .accessibilityValue(isRecording ? "Active" : "Idle")
    }

    // MARK: - Waveform View

    @ViewBuilder
    private var waveformView: some View {
        switch style {
        case .classic:
            ClassicWaveformView(
                audioLevel: audioLevel,
                isActive: isRecording,
                barColor: currentBarColor
            )

        case .neon:
            NeonWaveformView(
                waveformSamples: waveformSamples,
                audioLevel: audioLevel,
                isActive: isRecording
            )

        case .spectrum:
            SpectrumWaveformView(
                frequencyBands: frequencyBands,
                isActive: isRecording
            )

        case .circular:
            CircularSpectrumView(
                frequencyBands: frequencyBands,
                isActive: isRecording
            )

        case .pulseRings:
            PulseRingsView(
                audioLevel: audioLevel,
                isActive: isRecording
            )

        case .particles:
            ParticleFieldView(
                audioLevel: audioLevel,
                frequencyBands: frequencyBands,
                isActive: isRecording
            )
        }
    }

    // MARK: - State Helpers

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

    /// Whether the status dot should pulse. Tests can disable processing
    /// animations via `processingAnimated` to keep snapshots deterministic.
    private var shouldPulseStatusDot: Bool {
        if isRecording { return true }
        if isProcessing { return processingAnimated }
        return false
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

    private var statusTextColor: Color {
        switch status {
        case .recording:
            return .white.opacity(0.85)
        case .processing:
            return .white.opacity(0.7)
        case .success:
            return successColor
        case .error:
            return accentColor
        default:
            return .white.opacity(0.5)
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

#Preview("Container - Classic Recording") {
    WaveformContainer(
        status: .recording,
        audioLevel: 0.6,
        waveformSamples: [],
        frequencyBands: Array(repeating: 0.5, count: 8),
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}

#Preview("Container - Neon Recording") {
    WaveformContainer(
        status: .recording,
        audioLevel: 0.6,
        waveformSamples: (0..<64).map { _ in Float.random(in: -0.5...0.5) },
        frequencyBands: Array(repeating: 0.5, count: 8),
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
    .onAppear {
        AppDefaults.waveformStyle = .neon
    }
}

#Preview("Container - Spectrum Recording") {
    WaveformContainer(
        status: .recording,
        audioLevel: 0.6,
        waveformSamples: [],
        frequencyBands: [0.8, 0.6, 0.5, 0.4, 0.3, 0.25, 0.2, 0.15],
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
    .onAppear {
        AppDefaults.waveformStyle = .spectrum
    }
}

#Preview("Container - Ready") {
    WaveformContainer(
        status: .ready,
        audioLevel: 0,
        waveformSamples: [],
        frequencyBands: Array(repeating: 0, count: 8),
        onTap: {}
    )
    .frame(width: 280)
    .padding(40)
    .background(Color.black)
}
