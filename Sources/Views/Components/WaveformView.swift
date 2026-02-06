import SwiftUI
import AppKit

/// Recording control view - standard macOS look and feel
internal struct WaveformRecordingView: View {
    let status: AppStatus
    let audioLevel: Float
    let onTap: () -> Void

    var body: some View {
        ZStack {
            VisualEffectView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                header
                statusRow

                if isRecording {
                    RecordingWaveformView(level: clampedAudioLevel)
                        .frame(height: 28)
                        .padding(.top, 4)
                }

                Button(action: onTap) {
                    buttonSymbol
                        .font(.system(size: 54, weight: .regular))
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(buttonHelp)
                .accessibilityLabel(buttonHelp)
                .disabled(isProcessing)

            }
            .padding(16)
        }
        .frame(width: LayoutMetrics.RecordingWindow.size.width,
               height: LayoutMetrics.RecordingWindow.size.height)
        .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.RecordingWindow.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LayoutMetrics.RecordingWindow.cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .medium))
            Text("AudioWhisper")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(Color(nsColor: .labelColor))
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if isRecording {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 8, height: 8)
            } else if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else if isDownloadingModel {
                ProgressView()
                    .controlSize(.small)
            } else if let icon = status.icon {
                Image(systemName: icon)
                    .foregroundStyle(status.color)
            }

            Text(statusText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var buttonSymbol: some View {
        // Standard macOS recording controls keep "recording" as red, but the stop glyph should have strong
        // contrast (commonly white) against the red background.
        if case .recording = status {
            Image(systemName: buttonIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(nsColor: .systemRed))
                .contentTransition(.symbolEffect(.replace))
        } else {
            Image(systemName: buttonIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(buttonTint)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var statusText: String {
        switch status {
        case .recording:
            return "Recording…"
        case .processing(let message):
            return message
        case .downloadingModel(let message):
            return message
        case .success:
            return "Copied to clipboard"
        case .ready:
            return "Ready to record"
        case .permissionRequired:
            return "Microphone access required"
        case .error(let message):
            return message
        }
    }

    private var buttonTitle: String {
        switch status {
        case .recording:
            return "Stop Recording"
        case .processing:
            return "Processing…"
        case .downloadingModel:
            return "Start Recording"
        case .success:
            return "Paste"
        case .permissionRequired:
            return "Grant Permission"
        case .error:
            return "Try Again"
        case .ready:
            return "Start Recording"
        }
    }

    private var buttonIcon: String {
        switch status {
        case .recording:
            return "stop.circle.fill"
        case .processing:
            return "hourglass"
        case .downloadingModel:
            return "record.circle.fill"
        case .success:
            return "doc.on.clipboard"
        case .permissionRequired:
            return "mic.badge.plus"
        case .error:
            return "arrow.clockwise"
        case .ready:
            return "record.circle.fill"
        }
    }

    private var buttonTint: Color {
        switch status {
        case .recording, .ready, .downloadingModel:
            return Color(nsColor: .systemRed)
        case .success:
            return Color(nsColor: .systemGreen)
        case .processing:
            return Color(nsColor: .secondaryLabelColor)
        case .permissionRequired, .error:
            return Color.accentColor
        }
    }

    private var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    private var isProcessing: Bool {
        if case .processing = status { return true }
        return false
    }

    private var isDownloadingModel: Bool {
        if case .downloadingModel = status { return true }
        return false
    }

    private var clampedAudioLevel: Double {
        let level = Double(audioLevel)
        return min(1.0, max(0.0, level))
    }

    private var buttonHelp: String {
        switch status {
        case .recording:
            return "Stop recording"
        case .processing:
            return "Processing"
        case .downloadingModel:
            return "Start recording"
        case .success:
            return "Paste"
        case .permissionRequired:
            return "Grant microphone permission"
        case .error:
            return "Try again"
        case .ready:
            return "Start recording"
        }
    }
}

private struct RecordingWaveformView: View {
    let level: Double

    private let barCount = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let phase = Double(index) / Double(barCount)
                    let wave = (sin(time * 5 + phase * 8) + 1) / 2
                    let amplitude = max(0.2, level)
                    let height = CGFloat(6 + 22 * wave * amplitude)
                    Capsule()
                        .fill(Color(nsColor: .secondaryLabelColor))
                        .frame(width: 3, height: height)
                }
            }
        }
    }
}

#Preview("Recording Window") {
    WaveformRecordingView(status: .ready, audioLevel: 0.1, onTap: {})
        .padding(40)
        .background(Color(nsColor: .windowBackgroundColor))
}
