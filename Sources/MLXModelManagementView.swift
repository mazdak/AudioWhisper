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
            
            // Model List (shared row UI using adapters)
            VStack(spacing: 8) {
                let entries: [ModelEntry] = MLXModelManager.recommendedModels.map { m in
                    let startDownload = {
                        Task { @MainActor in
                            modelManager.isDownloading[m.repo] = true
                            modelManager.downloadProgress[m.repo] = "Starting download..."
                        }
                        Task { await modelManager.downloadModel(m.repo) }
                    }

                    return MLXEntry(
                        model: m,
                        isDownloaded: modelManager.downloadedModels.contains(m.repo),
                        isDownloading: modelManager.isDownloading[m.repo] ?? false,
                        statusText: modelManager.downloadProgress[m.repo],
                        sizeText: (modelManager.modelSizes[m.repo]).map(MLXModelManager.shared.formatBytes) ?? m.estimatedSize,
                        isSelected: selectedModelRepo == m.repo,
                        badgeText: isRecommended(m.repo) ? "RECOMMENDED" : nil,
                        onSelect: {
                            selectedModelRepo = m.repo
                            if !modelManager.downloadedModels.contains(m.repo) {
                                startDownload()
                            }
                        },
                        onDownload: startDownload,
                        onDelete: {
                            Task {
                                await modelManager.deleteModel(m.repo)
                                if selectedModelRepo == m.repo { selectedModelRepo = "mlx-community/Llama-3.2-3B-Instruct-4bit" }
                            }
                        }
                    )
                }
                ForEach(entries.indices, id: \.self) { i in
                    let e = entries[i]
                    UnifiedModelRow(
                        title: e.title,
                        subtitle: e.subtitle,
                        sizeText: e.sizeText,
                        statusText: e.statusText,
                        statusColor: e.statusColor,
                        isDownloaded: e.isDownloaded,
                        isDownloading: e.isDownloading,
                        isSelected: e.isSelected,
                        badgeText: e.badgeText,
                        onSelect: e.onSelect,
                        onDownload: e.onDownload,
                        onDelete: e.onDelete
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

    private func isRecommended(_ repo: String) -> Bool {
        return repo == "mlx-community/Llama-3.2-3B-Instruct-4bit"
    }
}
