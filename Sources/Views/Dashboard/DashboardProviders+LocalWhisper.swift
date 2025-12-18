import SwiftUI

internal extension DashboardProvidersView {
    // MARK: - Local Whisper Section
    @ViewBuilder
    var localWhisperCard: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("02")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)
                
                Text("LOCAL MODELS")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
                
                Spacer()
                
                Button {
                    Task { await modelManager.refreshModelStates() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 0) {
                // Model list
                ForEach(WhisperModel.allCases, id: \.self) { model in
                    whisperModelRow(model)
                    
                    if model != WhisperModel.allCases.last {
                        Divider()
                            .background(DashboardTheme.rule)
                    }
                }
                
                Divider().background(DashboardTheme.rule)
                
                // Storage footer
                storageFooter
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
            
            // Error message
            if let error = downloadError {
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                    Text(error)
                        .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                }
                .foregroundStyle(Color(red: 0.75, green: 0.30, blue: 0.28))
                .padding(DashboardTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.75, green: 0.30, blue: 0.28).opacity(0.08))
                )
            }
        }
    }
    
    private func whisperModelRow(_ model: WhisperModel) -> some View {
        let isSelected = selectedWhisperModel == model
        let isDownloaded = modelManager.downloadedModels.contains(model)
        let stage = modelManager.getDownloadStage(for: model)
        let isDownloading = stage?.isActive ?? false
        
        return HStack(spacing: DashboardTheme.Spacing.md) {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 10, height: 10)
                }
            }
            
            // Model info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DashboardTheme.Spacing.sm) {
                    Text(model.displayName)
                        .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)
                    
                    if model == .base {
                        Text("RECOMMENDED")
                            .font(DashboardTheme.Fonts.sans(9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DashboardTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                
                Text(model.description)
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
            
            // Size
            Text(model.fileSize)
                .font(DashboardTheme.Fonts.mono(11, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)
            
            // Status/Action
            Group {
                if isDownloading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        
                        if let stage = stage {
                            Text(stage.displayText)
                                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                                .foregroundStyle(DashboardTheme.inkMuted)
                        }
                    }
                    .frame(minWidth: 80)
                } else if isDownloaded {
                    HStack(spacing: 6) {
                        Text("Installed")
                            .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.60, blue: 0.40))
                        
                        Button {
                            deleteModel(model)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.inkMuted)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        downloadModel(model)
                    } label: {
                        Text("Get")
                            .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(DashboardTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedWhisperModel = model
            if !isDownloaded && !isDownloading {
                downloadModel(model)
            }
        }
    }
    
    private var storageFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Storage")
                    .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text("~/Documents/huggingface/models/")
                    .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkFaint)
            }
            
            Spacer()
            
            let limitBytes = Int64(maxModelStorageGB * 1024 * 1024 * 1024)
            
            Text("\(formatBytes(totalModelsSize)) / \(formatBytes(limitBytes))")
                .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                .foregroundStyle(DashboardTheme.inkMuted)
            
            Picker("", selection: $maxModelStorageGB) {
                Text("1 GB").tag(1.0)
                Text("2 GB").tag(2.0)
                Text("5 GB").tag(5.0)
                Text("10 GB").tag(10.0)
            }
            .labelsHidden()
            .frame(width: 80)
        }
        .padding(DashboardTheme.Spacing.md)
    }
    
    // MARK: - Actions
    private func downloadModel(_ model: WhisperModel) {
        downloadError = nil
        downloadStartTime[model] = Date()
        Task {
            do {
                try await modelManager.downloadModel(model)
                downloadStartTime.removeValue(forKey: model)
                loadModelStates()
            } catch {
                downloadError = error.localizedDescription
                downloadStartTime.removeValue(forKey: model)
            }
        }
    }

    private func deleteModel(_ model: WhisperModel) {
        Task {
            do {
                try await modelManager.deleteModel(model)
                loadModelStates()
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    func loadModelStates() {
        Task {
            let models = await modelManager.getDownloadedModels()
            let totalSize = await modelManager.getTotalModelsSize()

            var states: [WhisperModel: Bool] = [:]
            for model in WhisperModel.allCases {
                let isDownloaded = await modelManager.isModelDownloaded(model)
                states[model] = isDownloaded
            }

            await MainActor.run {
                self.downloadedModels = models
                self.totalModelsSize = totalSize
                self.modelDownloadStates = states
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
