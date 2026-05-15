import SwiftUI

extension DashboardProvidersView {
    // MARK: - Correction Section
    var correctionSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("02")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)

                Text("POST-PROCESSING")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }

            VStack(spacing: 0) {
                // Mode selection
                correctionModeSection

                let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off

                if mode == .localMLX {
                    Divider().background(DashboardTheme.rule)
                    correctionMLXSection
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DashboardTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DashboardTheme.rule, lineWidth: 1)
            )
        }
    }

    var correctionModeSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Semantic Correction")
                    .font(DashboardTheme.Fonts.sans(15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)

                Text("Clean up grammar, punctuation, and filler words after transcription")
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }

            HStack(alignment: .center, spacing: DashboardTheme.Spacing.sm) {
                Text("Mode")
                    .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                    .foregroundStyle(DashboardTheme.inkMuted)

                Spacer()

                Picker("", selection: $semanticCorrectionModeRaw) {
                    ForEach(SemanticCorrectionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .padding(DashboardTheme.Spacing.lg)
    }

    var correctionMLXSection: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            // Environment status (shares with Parakeet)
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Image(systemName: envReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(envReady ? DashboardTheme.success : DashboardTheme.accent)

                Text(envReady ? "Environment ready" : "Setup required")
                    .font(DashboardTheme.Fonts.sans(12, weight: .medium))
                    .foregroundStyle(envReady ? DashboardTheme.success : DashboardTheme.accent)

                Spacer()

                if !envReady {
                    Button("Install") {
                        runCorrectionSetup()
                    }
                    .buttonStyle(PaperAccentButtonStyle())
                }
            }

            if envReady {
                // Model list header
                HStack {
                    Text("Correction Model")
                        .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)

                    Spacer()

                    if mlxModelManager.totalCacheSize > 0 {
                        Text(mlxModelManager.formatBytes(mlxModelManager.totalCacheSize))
                            .font(DashboardTheme.Fonts.mono(10, weight: .medium))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }

                    Button {
                        isRefreshingMLXModels = true
                        Task {
                            await mlxModelManager.refreshModelList()
                            await MainActor.run { isRefreshingMLXModels = false }
                        }
                    } label: {
                        if isRefreshingMLXModels {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DashboardTheme.inkMuted)
                }

                // Model rows
                VStack(spacing: 0) {
                    ForEach(MLXModelManager.recommendedModels, id: \.repo) { model in
                        correctionModelRow(model)

                        if model.repo != MLXModelManager.recommendedModels.last?.repo {
                            Divider().background(DashboardTheme.rule)
                        }
                    }
                }
                .background(DashboardTheme.pageBg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DashboardTheme.rule, lineWidth: 1)
                )

                // Footer
                HStack {
                    Text("~/.cache/huggingface/hub")
                        .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                        .foregroundStyle(DashboardTheme.inkFaint)

                    Spacer()

                    if mlxModelManager.unusedModelCount > 0 {
                        Button {
                            Task { await mlxModelManager.cleanupUnusedModels() }
                        } label: {
                            Text("Clean up \(mlxModelManager.unusedModelCount) old")
                                .font(DashboardTheme.Fonts.sans(10, weight: .medium))
                        }
                        .buttonStyle(PaperButtonStyle())
                    }
                }
            }
        }
        .padding(DashboardTheme.Spacing.md)
    }

    func correctionModelRow(_ model: MLXModel) -> some View {
        let isSelected = semanticCorrectionModelRepo == model.repo
        let isDownloaded = mlxModelManager.downloadedModels.contains(model.repo)
        let isDownloading = mlxModelManager.isDownloading[model.repo] ?? false
        let isRecommended = model.repo == "mlx-community/Qwen3-1.7B-4bit"

        return HStack(spacing: DashboardTheme.Spacing.sm) {
            // Selection
            ZStack {
                Circle()
                    .stroke(isSelected ? DashboardTheme.accent : DashboardTheme.rule, lineWidth: 1.5)
                    .frame(width: 16, height: 16)

                if isSelected {
                    Circle()
                        .fill(DashboardTheme.accent)
                        .frame(width: 8, height: 8)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                        .foregroundStyle(DashboardTheme.ink)

                    if isRecommended {
                        Text("REC")
                            .font(DashboardTheme.Fonts.sans(8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DashboardTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }

                Text(model.description)
                    .font(DashboardTheme.Fonts.sans(10, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }

            Spacer()

            // Size
            Text(mlxModelManager.modelSizes[model.repo].map { mlxModelManager.formatBytes($0) } ?? model.estimatedSize)
                .font(DashboardTheme.Fonts.mono(10, weight: .regular))
                .foregroundStyle(DashboardTheme.inkMuted)

            // Action
            if isDownloading {
                ProgressView().controlSize(.small)
            } else if isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DashboardTheme.success)

                    Button {
                        Task { await mlxModelManager.deleteModel(model.repo) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    Task {
                        await MainActor.run {
                            mlxModelManager.isDownloading[model.repo] = true
                        }
                        await mlxModelManager.downloadModel(model.repo)
                    }
                } label: {
                    Text("Get")
                        .font(DashboardTheme.Fonts.sans(10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DashboardTheme.Spacing.sm)
        .padding(.vertical, DashboardTheme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            semanticCorrectionModelRepo = model.repo
            if !isDownloaded && !isDownloading {
                Task {
                    await MainActor.run {
                        mlxModelManager.isDownloading[model.repo] = true
                    }
                    await mlxModelManager.downloadModel(model.repo)
                }
            }
        }
    }

    func runCorrectionSetup() {
        setupStatus = "Installing correction dependencies…"
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
        Task {
            do {
                _ = try await UvBootstrap.ensureVenv(userPython: nil) { msg in
                    Task { @MainActor in
                        setupLogs += (setupLogs.isEmpty ? "" : "\n") + msg
                    }
                }
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✓ Environment ready"
                    envReady = true
                    hasSetupLocalLLM = true
                }
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run { showSetupSheet = false }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✗ Setup failed"
                    setupLogs += "\nError: \(error.localizedDescription)"
                }
            }
        }
    }
}
