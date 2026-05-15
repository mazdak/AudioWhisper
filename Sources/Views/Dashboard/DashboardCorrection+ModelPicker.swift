import SwiftUI

extension DashboardCorrectionView {
    // MARK: - Local MLX Card
    var localMLXCard: some View {
        SettingsSectionCard(title: "Local MLX", icon: "cpu") {
            VStack(alignment: .leading, spacing: 14) {
                envStatusRow

                if !envReady {
                    Button {
                        runUvSetupSheet(title: "Setting up Local LLM dependencies…") {
                            checkEnvReady()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Install Dependencies")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DashboardTheme.accent)
                }

                modelList

                verifyRow
            }
        }
    }

    var envStatusRow: some View {
        HStack(spacing: 10) {
            if isCheckingEnv { ProgressView().controlSize(.small) }
            Image(systemName: envReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(envReady ? .green : .yellow)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                Text(envReady ? "Environment ready" : "Python environment missing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DashboardTheme.ink)
                Text("Managed by uv and required for running MLX locally.")
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.inkMuted)
            }

            Spacer()

            Button {
                checkEnvReady()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(DashboardTheme.accent)
            .disabled(isCheckingEnv)
        }
    }

    var modelList: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack {
                Text("MLX Models")
                    .font(DashboardTheme.Fonts.sans(13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if modelManager.totalCacheSize > 0 {
                    Text(modelManager.formatBytes(modelManager.totalCacheSize))
                        .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)
                }

                Button {
                    isRefreshingModels = true
                    Task {
                        await modelManager.refreshModelList()
                        await MainActor.run { isRefreshingModels = false }
                    }
                } label: {
                    if isRefreshingModels {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DashboardTheme.inkMuted)
                .disabled(isRefreshingModels)
            }

            VStack(spacing: 0) {
                ForEach(mlxEntries.indices, id: \.self) { idx in
                    let entry = mlxEntries[idx]
                    modelRow(entry: entry)

                    if idx < mlxEntries.count - 1 {
                        Divider()
                            .background(DashboardTheme.rule)
                    }
                }
            }
            .background(DashboardTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )

            HStack {
                Text("Models cached at ~/.cache/huggingface/hub")
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkFaint)

                Spacer()

                if modelManager.unusedModelCount > 0 {
                    Button {
                        Task {
                            await modelManager.cleanupUnusedModels()
                        }
                    } label: {
                        Text("Clean up \(modelManager.unusedModelCount) old model\(modelManager.unusedModelCount == 1 ? "" : "s")")
                            .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                    }
                    .buttonStyle(PaperButtonStyle())
                }
            }
        }
    }

    func modelRow(entry: ModelEntry) -> some View {
        HStack(spacing: DashboardTheme.Spacing.sm) {
            // Selection indicator
            ZStack {
                Circle()
                    .stroke(entry.isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: 1.5)
                    .frame(width: 18, height: 18)

                if entry.isSelected {
                    Circle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 10, height: 10)
                }
            }

            // Model info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DashboardTheme.Spacing.xs) {
                    Text(entry.title)
                        .font(DashboardTheme.Fonts.mono(12, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)

                    if let badge = entry.badgeText {
                        Text(badge)
                            .font(DashboardTheme.Fonts.sans(9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DashboardTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(entry.subtitle)
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }

            Spacer()

            // Size
            Text(entry.sizeText ?? "")
                .font(DashboardTheme.Fonts.mono(11, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)

            // Status/Action
            if entry.isDownloading {
                DownloadProgressView(
                    state: .downloading(
                        progress: 0,
                        statusText: entry.statusText
                    )
                )
                .frame(maxWidth: 160)
            } else if entry.isDownloaded {
                HStack(spacing: 4) {
                    Text("Installed")
                        .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                        .foregroundStyle(DashboardTheme.inkMuted)

                    Button {
                        entry.onDelete()
                    } label: {
                        Text("Delete")
                            .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                    }
                    .buttonStyle(PaperButtonStyle())
                }
            } else {
                Button {
                    entry.onDownload()
                } label: {
                    Text("Get")
                        .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                }
                .buttonStyle(PaperAccentButtonStyle())
            }
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.sm + 2)
        .contentShape(Rectangle())
        .onTapGesture {
            entry.onSelect()
        }
    }

    // MARK: - Model Entries
    var mlxEntries: [ModelEntry] {
        MLXModelManager.recommendedModels.map { model in
            let startDownload = {
                Task { @MainActor in
                    modelManager.isDownloading[model.repo] = true
                    modelManager.downloadProgress[model.repo] = "Starting download..."
                }
                Task { await modelManager.downloadModel(model.repo) }
            }

            // Badge logic: recommend Qwen3-1.7B as best balance
            let badge: String? = model.repo == "mlx-community/Qwen3-1.7B-4bit" ? "RECOMMENDED" : nil

            return MLXEntry(
                model: model,
                isDownloaded: modelManager.downloadedModels.contains(model.repo),
                isDownloading: modelManager.isDownloading[model.repo] ?? false,
                statusText: modelManager.downloadProgress[model.repo],
                sizeText: (modelManager.modelSizes[model.repo]).map(modelManager.formatBytes) ?? model.estimatedSize,
                isSelected: semanticCorrectionModelRepo == model.repo,
                badgeText: badge,
                onSelect: {
                    semanticCorrectionModelRepo = model.repo
                    if !modelManager.downloadedModels.contains(model.repo) {
                        startDownload()
                    }
                },
                onDownload: startDownload,
                onDelete: {
                    Task {
                        await modelManager.deleteModel(model.repo)
                        if semanticCorrectionModelRepo == model.repo {
                            semanticCorrectionModelRepo = "mlx-community/Qwen3-1.7B-4bit"
                        }
                    }
                }
            )
        }
    }
}
