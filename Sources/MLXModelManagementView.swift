import SwiftUI

struct MLXModelManagementView: View {
    @StateObject private var modelManager = MLXModelManager.shared
    @Binding var selectedModelRepo: String
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                Text("MLX Models")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if modelManager.totalCacheSize > 0 {
                    Text(modelManager.formatBytes(modelManager.totalCacheSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Button(action: {
                    isRefreshing = true
                    Task {
                        await modelManager.refreshModelList()
                        await MainActor.run {
                            isRefreshing = false
                        }
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .help("Refresh model list to check downloaded models")
            }
            
            // Model List
            VStack(spacing: 8) {
                ForEach(MLXModelManager.recommendedModels) { model in
                    MLXModelCard(
                        model: model,
                        isDownloaded: modelManager.downloadedModels.contains(model.repo),
                        isDownloading: modelManager.isDownloading[model.repo] ?? false,
                        downloadProgress: modelManager.downloadProgress[model.repo],
                        actualSize: modelManager.modelSizes[model.repo],
                        isSelected: selectedModelRepo == model.repo,
                        onSelect: {
                            selectedModelRepo = model.repo
                        },
                        onDownload: {
                            // Immediately show downloading state
                            Task { @MainActor in
                                modelManager.isDownloading[model.repo] = true
                                modelManager.downloadProgress[model.repo] = "Starting download..."
                            }
                            Task {
                                await modelManager.downloadModel(model.repo)
                            }
                        },
                        onDelete: {
                            Task {
                                await modelManager.deleteModel(model.repo)
                                if selectedModelRepo == model.repo {
                                    selectedModelRepo = "mlx-community/gemma-2-2b-it-4bit"
                                }
                            }
                        }
                    )
                }
            }
            
            // Info text with clickable path
            VStack(alignment: .leading, spacing: 4) {
                Text("Models are stored in:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("~/.cache/huggingface/hub/")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                    
                    Button(action: {
                        let path = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".cache/huggingface/hub")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
                    }) {
                        Image(systemName: "folder")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Open in Finder")
                }
            }
        }
    }
}

struct MLXModelCard: View {
    let model: MLXModel
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: String?
    let actualSize: Int64?
    let isSelected: Bool
    
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    @State private var isDeleting = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection radio button (only for downloaded models)
            if isDownloaded {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
                    .onTapGesture {
                        onSelect()
                    }
            } else {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary.opacity(0.5))
                    .font(.system(size: 16))
            }
            
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                    if isRecommended(model.repo) {
                        Text("RECOMMENDED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let progress = downloadProgress {
                    Text(progress)
                        .font(.caption2)
                        .foregroundColor(progress.contains("Error") || progress.contains("Please") ? .red : .blue)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer()
            
            // Size info
            VStack(alignment: .trailing, spacing: 2) {
                if let actualSize = actualSize {
                    Text(MLXModelManager.shared.formatBytes(actualSize))
                        .font(.caption)
                        .foregroundColor(.primary)
                } else {
                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isDownloaded {
                    Text("Installed")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Action button
            if isDownloading {
                VStack(spacing: 2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
            } else if isDeleting {
                VStack(spacing: 2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Deleting...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
            } else if isDownloaded {
                Button("Delete") {
                    isDeleting = true
                    Task {
                        onDelete()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            isDeleting = false
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 60)
                .disabled(isDeleting)
            } else {
                Button("Get") {
                    onDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(width: 60)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isDownloaded {
                onSelect()
            }
        }
    }

    private func isRecommended(_ repo: String) -> Bool {
        return repo == "mlx-community/gemma-2-2b-it-4bit"
    }
}
