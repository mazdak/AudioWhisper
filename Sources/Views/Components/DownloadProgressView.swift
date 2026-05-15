import SwiftUI

/// Unified download/verify state UI for model downloads (WhisperKit, Parakeet,
/// MLX correction). Replaces the previous mix of ad-hoc ProgressView usages,
/// animated opacity flags, and modal sheets across the Dashboard.
///
/// Owners pass in the current state plus retry/cancel callbacks. The component
/// owns the visual styling so the experience is consistent across providers.
public enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double, statusText: String? = nil)
    case verifying
    case failed(message: String)
    case verified

    public static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.verifying, .verifying), (.verified, .verified):
            return true
        case let (.downloading(lp, lt), .downloading(rp, rt)):
            return lp == rp && lt == rt
        case let (.failed(l), .failed(r)):
            return l == r
        default:
            return false
        }
    }
}

public struct DownloadProgressView: View {
    let state: DownloadState
    var onRetry: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    public init(state: DownloadState,
                onRetry: (() -> Void)? = nil,
                onCancel: (() -> Void)? = nil) {
        self.state = state
        self.onRetry = onRetry
        self.onCancel = onCancel
    }

    public var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .downloading(let progress, let statusText):
                HStack(spacing: 8) {
                    ProgressView(value: progress.clamped(to: 0...1))
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 240)
                    if let statusText {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let onCancel {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                }
            case .verifying:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Verifying model…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .failed(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let onRetry {
                        Button("Retry", action: onRetry)
                            .controlSize(.small)
                    }
                }
            case .verified:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return ""
        case .downloading(let p, let t):
            return "Downloading \(Int(p * 100)) percent. \(t ?? "")"
        case .verifying: return "Verifying model"
        case .failed(let m): return "Download failed: \(m)"
        case .verified: return "Model ready"
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#if DEBUG
#Preview("DownloadProgressView") {
    VStack(alignment: .leading, spacing: 12) {
        DownloadProgressView(state: .downloading(progress: 0.42, statusText: "234 MB / 558 MB"))
        DownloadProgressView(state: .verifying)
        DownloadProgressView(state: .failed(message: "Network error"), onRetry: {})
        DownloadProgressView(state: .verified)
    }
    .padding()
}
#endif
