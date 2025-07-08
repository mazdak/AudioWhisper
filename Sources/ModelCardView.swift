import SwiftUI

struct ModelCardView: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool
    let downloadStage: DownloadStage?
    let estimatedTimeRemaining: TimeInterval?
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void
    
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with model name and status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if model == .base {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status indicator
                statusIndicator
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Model details
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "externaldrive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(model.fileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Speed/accuracy indicator
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < model.accuracyRating ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                    Text("Accuracy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            
            // Download progress or warning
            if let stage = downloadStage, stage.isActive {
                downloadProgressView(stage: stage)
            } else if !isDownloaded && model.estimatedSize > 1000 * 1024 * 1024 {
                warningView
            }
            
            // Action buttons
            actionButtons
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(8)
        .onTapGesture {
            if isDownloaded {
                onSelect()
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        if let stage = downloadStage {
            switch stage {
            case .preparing, .downloading, .processing, .completing:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(stage.displayText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            case .ready:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Ready!")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            case .failed(_):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Failed")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        } else if isDownloaded {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                if isSelected {
                    Text("Selected")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                } else {
                    Text("Downloaded")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("Not Downloaded")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func downloadProgressView(stage: DownloadStage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stage.displayText)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                if let timeRemaining = estimatedTimeRemaining {
                    Text(formatTimeRemaining(timeRemaining))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Indeterminate progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: animateProgress ? geometry.size.width * 0.7 : geometry.size.width * 0.3, height: 3)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateProgress)
                }
            }
            .frame(height: 3)
            .onAppear {
                animateProgress = true
            }
            .cornerRadius(1.5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var warningView: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi")
                .foregroundColor(.orange)
                .font(.caption)
            Text("Large download - ensure good WiFi connection")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if isDownloaded {
                if !isSelected {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .controlSize(.small)
            } else {
                Button(action: onDownload) {
                    HStack(spacing: 4) {
                        if downloadStage?.isActive == true {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                        }
                        Text(downloadStage?.isActive == true ? "Downloading..." : "Download")
                            .font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(downloadStage?.isActive == true)
                
                Spacer()
            }
        }
        .padding(.top, 8)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.1)
        } else if isDownloaded {
            return Color.green.opacity(0.05)
        } else {
            return Color.secondary.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isDownloaded {
            return Color.green.opacity(0.3)
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        } else {
            return "\(seconds)s remaining"
        }
    }
}

// Extension to provide accuracy ratings for models
extension WhisperModel {
    var accuracyRating: Int {
        switch self {
        case .tiny: return 2
        case .base: return 3
        case .small: return 4
        case .largeTurbo: return 5
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ModelCardView(
            model: .base,
            isSelected: true,
            isDownloaded: true,
            downloadStage: nil,
            estimatedTimeRemaining: nil,
            onDownload: {},
            onDelete: {},
            onSelect: {}
        )
        
        ModelCardView(
            model: .largeTurbo,
            isSelected: false,
            isDownloaded: false,
            downloadStage: .downloading,
            estimatedTimeRemaining: 125,
            onDownload: {},
            onDelete: {},
            onSelect: {}
        )
        
        ModelCardView(
            model: .tiny,
            isSelected: false,
            isDownloaded: false,
            downloadStage: nil,
            estimatedTimeRemaining: nil,
            onDownload: {},
            onDelete: {},
            onSelect: {}
        )
    }
    .padding()
    .frame(width: 400)
}