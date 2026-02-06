import SwiftUI
import AppKit

internal struct DashboardCorrectionView: View {
    // Stored preferences
    @AppStorage(AppDefaults.Keys.semanticCorrectionMode) private var semanticCorrectionModeRaw = AppDefaults.defaultSemanticCorrectionMode.rawValue
    @AppStorage(AppDefaults.Keys.semanticCorrectionModelRepo) private var semanticCorrectionModelRepo = AppDefaults.defaultSemanticCorrectionModelRepo
    @AppStorage(AppDefaults.Keys.hasSetupLocalLLM) private var hasSetupLocalLLM = false
    @AppStorage(AppDefaults.Keys.hasSetupParakeet) private var hasSetupParakeet = false

    // Model management
    @State private var modelManager = MLXModelManager.shared

    // Environment + verification state
    @State private var envReady = false
    @State private var isCheckingEnv = false
    @State private var isSettingUp = false
    @State private var showSetupSheet = false
    @State private var setupStatus: String?
    @State private var setupLogs = ""
    @State private var isVerifyingMLX = false
    @State private var mlxVerifyMessage: String?

    @State private var isRefreshingModels = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Semantic Correction")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DashboardTheme.ink)

                SettingsSectionCard(title: "Correction Mode", icon: "text.badge.checkmark") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose where semantic correction runs after transcription.")
                            .font(.footnote)
                            .foregroundStyle(DashboardTheme.inkMuted)

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
                            .tint(DashboardTheme.accent)
                        }
                    }
                }

                let mode = SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off
                switch mode {
                case .off:
                    SettingsSectionCard(title: "Correction Disabled", icon: "pause.circle") {
                        Text("Semantic correction is turned off. Turn it on to improve readability and formatting of transcriptions.")
                            .font(.footnote)
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }

                case .localMLX:
                    localMLXCard

                case .cloud:
                    SettingsSectionCard(title: "Cloud Correction", icon: "cloud.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Corrections run on the same cloud provider you chose for transcription (OpenAI or Gemini).")
                                .font(.footnote)
                                .foregroundStyle(DashboardTheme.inkMuted)
                            Text("Use this when you prefer not to download local models or want maximum quality using server models.")
                                .font(.caption)
                                .foregroundStyle(DashboardTheme.inkFaint)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(DashboardTheme.pageBg)
        .onAppear {
            if (SemanticCorrectionMode(rawValue: semanticCorrectionModeRaw) ?? .off) == .localMLX {
                checkEnvReady()
            }
            Task {
                isRefreshingModels = true
                await modelManager.refreshModelList()
                await MainActor.run { isRefreshingModels = false }
            }
        }
        .onChange(of: semanticCorrectionModeRaw) { _, newValue in
            if SemanticCorrectionMode(rawValue: newValue) == .localMLX {
                checkEnvReady()
            }
        }
        .sheet(isPresented: $showSetupSheet) {
            SetupEnvironmentSheet(
                isPresented: $showSetupSheet,
                isRunning: $isSettingUp,
                logs: $setupLogs,
                title: setupStatus ?? "Setting up environment…",
                onStart: { }
            )
        }
    }

    // MARK: - Subviews
    private var localMLXCard: some View {
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

    private var envStatusRow: some View {
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

    private var modelList: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.md) {
            HStack {
                Text("MLX Models")
                    .font(DashboardTheme.Fonts.sans(13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)

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
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    private func modelRow(entry: ModelEntry) -> some View {
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
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 60)
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
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    entry.onDownload()
                } label: {
                    Text("Get")
                        .font(DashboardTheme.Fonts.sans(11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, DashboardTheme.Spacing.md)
        .padding(.vertical, DashboardTheme.Spacing.sm + 2)
        .contentShape(Rectangle())
        .onTapGesture {
            entry.onSelect()
        }
    }

    private var verifyRow: some View {
        HStack(spacing: 10) {
            if isVerifyingMLX { ProgressView().controlSize(.small) }
            Button(isVerifyingMLX ? "Verifying…" : "Verify MLX Model") {
                verifyMLXModel()
            }
            .buttonStyle(.bordered)
            .tint(DashboardTheme.accent)
            .disabled(isVerifyingMLX)

            if let msg = mlxVerifyMessage, !msg.isEmpty {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers (copied from SettingsView)
    private func runUvSetupSheet(title: String, onComplete: (() -> Void)? = nil) {
        setupStatus = title
        setupLogs = ""
        isSettingUp = true
        showSetupSheet = true
        Task {
            do {
                _ = try UvBootstrap.ensureVenv(userPython: nil) { msg in
                    Task { @MainActor in
                        setupLogs += (setupLogs.isEmpty ? "" : "\n") + msg
                    }
                }
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✓ Environment ready"
                    envReady = true
                    hasSetupLocalLLM = true
                    hasSetupParakeet = true
                }
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    showSetupSheet = false
                    onComplete?()
                }
            } catch {
                await MainActor.run {
                    isSettingUp = false
                    setupStatus = "✗ Setup failed"
                    let msg = error.localizedDescription.isEmpty ? String(describing: error) : error.localizedDescription
                    setupLogs += (setupLogs.isEmpty ? "" : "\n") + "Error: \(msg)"
                    envReady = false
                }
            }
        }
    }

    private func checkEnvReady() {
        isCheckingEnv = true
        Task {
            let fm = FileManager.default
            let py = venvPythonPath()
            var ready = false
            if fm.isExecutableFile(atPath: py) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: py)
                process.arguments = ["-c", "import mlx_lm; print('OK')"]
                process.standardOutput = Pipe()
                process.standardError = Pipe()
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 { ready = true }
                } catch {
                    ready = false
                }
            }
            await MainActor.run {
                self.envReady = ready
                self.isCheckingEnv = false
                if ready {
                    self.hasSetupParakeet = true
                    self.hasSetupLocalLLM = true
                }
            }
        }
    }

    private func venvPythonPath() -> String {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let base = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/bin/python3").path
        return base ?? ""
    }

    private func verifyMLXModel() {
        isVerifyingMLX = true
        mlxVerifyMessage = "Checking model (offline)…"
        let repo = semanticCorrectionModelRepo
        Task {
            do {
                let py = try await Task.detached(priority: .userInitiated) {
                    try UvBootstrap.ensureVenv(userPython: nil) { _ in }
                }.value
                let pythonPath = py.path
                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)

                guard let scriptURL = ResourceLocator.pythonScriptURL(named: "verify_mlx") else {
                    await MainActor.run { mlxVerifyMessage = "Script not found"; isVerifyingMLX = false }
                    return
                }

                process.arguments = [scriptURL.path, repo]
                let out = Pipe(); let err = Pipe()
                process.standardOutput = out; process.standardError = err

                let messageStore = VerificationMessageStore()
                out.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    for line in s.split(separator: "\n").map(String.init) {
                        if let d = line.data(using: .utf8),
                           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                           let msg = j["message"] as? String {
                            Task {
                                await messageStore.updateStdout(msg)
                                await MainActor.run { mlxVerifyMessage = msg }
                            }
                        }
                    }
                }
                err.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let msg = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { @MainActor in mlxVerifyMessage = msg }
                }

                try process.run()
                let timeout = Task { try await Task.sleep(for: .seconds(180)); if process.isRunning { process.terminate() } }
                await Task.detached { process.waitUntilExit() }.value
                timeout.cancel()
                let lastMsg = await messageStore.stdoutMessage()
                await MainActor.run {
                    isVerifyingMLX = false
                    if process.terminationStatus == 0 {
                        mlxVerifyMessage = lastMsg.isEmpty ? "Model verified" : lastMsg
                        Task { await MLXModelManager.shared.refreshModelList() }
                    } else {
                        if (mlxVerifyMessage ?? "").isEmpty { mlxVerifyMessage = "Verification failed" }
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingMLX = false
                    mlxVerifyMessage = "Verification error: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Model Entries
    private var mlxEntries: [ModelEntry] {
        MLXModelManager.recommendedModels.map { model in
            let startDownload = {
                Task { @MainActor in
                    modelManager.isDownloading[model.repo] = true
                    modelManager.downloadProgress[model.repo] = "Starting download..."
                }
                Task { await modelManager.downloadModel(model.repo) }
            }
            
            // Badge logic: recommend Qwen3-1.7B as best balance
            let badge: String? = model.repo == AppDefaults.defaultSemanticCorrectionModelRepo ? "RECOMMENDED" : nil

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
                            semanticCorrectionModelRepo = AppDefaults.defaultSemanticCorrectionModelRepo
                        }
                    }
                }
            )
        }
    }

    // MARK: - Scoped helper for verification messages
    private actor VerificationMessageStore {
        private var stdout: String = ""
        private var stderr: String = ""

        func updateStdout(_ value: String) { stdout = value }
        func updateStderr(_ value: String) { stderr = value }
        func stdoutMessage() -> String { stdout }
        func stderrMessage() -> String { stderr }
    }
}
