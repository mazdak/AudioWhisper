import SwiftUI
import AppKit

private actor VerificationMessageStore {
    private var stdout: String = ""
    private var stderr: String = ""

    func updateStdout(_ value: String) { stdout = value }
    func updateStderr(_ value: String) { stderr = value }
    func stdoutMessage() -> String { stdout }
    func stderrMessage() -> String { stderr }
}

internal extension DashboardProvidersView {
    // MARK: - Parakeet Section
    @ViewBuilder
    var parakeetCard: some View {
        VStack(alignment: .leading, spacing: DashboardTheme.Spacing.lg) {
            // Section label
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Text("02")
                    .font(DashboardTheme.Fonts.mono(11, weight: .medium))
                    .foregroundStyle(DashboardTheme.accent)
                
                Text("PARAKEET SETUP")
                    .font(DashboardTheme.Fonts.sans(11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.inkMuted)
                    .tracking(1.5)
            }
            
            VStack(spacing: 0) {
                // Environment status - prominent
                environmentStatusSection
                
                Divider().background(DashboardTheme.rule)
                
                // Model selection
                modelSelectionSection
                
                // Verification message
                if let msg = parakeetVerifyMessage, !msg.isEmpty {
                    Divider().background(DashboardTheme.rule)
                    
                    HStack(spacing: DashboardTheme.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.inkMuted)
                        
                        Text(msg)
                            .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                            .foregroundStyle(DashboardTheme.inkMuted)
                    }
                    .padding(DashboardTheme.Spacing.md)
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
            
            // Info footer
            HStack(spacing: DashboardTheme.Spacing.sm) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.inkFaint)
                
                Text("Runs locally on Apple Silicon • ~2.5 GB disk space")
                    .font(DashboardTheme.Fonts.sans(11, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkFaint)
            }
        }
    }
    
    private var environmentStatusSection: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(envReady ? Color(red: 0.35, green: 0.60, blue: 0.40).opacity(0.12) : DashboardTheme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                if isCheckingEnv {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: envReady ? "checkmark" : "arrow.down.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(envReady ? Color(red: 0.35, green: 0.60, blue: 0.40) : DashboardTheme.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(envReady ? "Environment Ready" : "Setup Required")
                    .font(DashboardTheme.Fonts.sans(15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text("Python dependencies for local neural inference")
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
            
            if !envReady {
                Button {
                    runUvSetupSheet(title: "Installing Parakeet dependencies…")
                } label: {
                    Text("Install")
                        .font(DashboardTheme.Fonts.sans(13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(DashboardTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    verifyParakeetModel()
                } label: {
                    HStack(spacing: 4) {
                        if isVerifyingParakeet {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isVerifyingParakeet ? "Verifying…" : "Verify")
                            .font(DashboardTheme.Fonts.sans(13, weight: .medium))
                    }
                    .foregroundStyle(DashboardTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DashboardTheme.rule, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isVerifyingParakeet)
            }
        }
        .padding(DashboardTheme.Spacing.lg)
    }
    
    private var modelSelectionSection: some View {
        HStack(spacing: DashboardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Model")
                    .font(DashboardTheme.Fonts.sans(14, weight: .medium))
                    .foregroundStyle(DashboardTheme.ink)
                
                Text("Downloaded on first use")
                    .font(DashboardTheme.Fonts.sans(12, weight: .regular))
                    .foregroundStyle(DashboardTheme.inkMuted)
            }
            
            Spacer()
            
            Picker("", selection: $selectedParakeetModel) {
                ForEach(ParakeetModel.allCases, id: \.self) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
        .padding(DashboardTheme.Spacing.md)
        .onChange(of: selectedParakeetModel) { _, _ in
            Task { await MLXModelManager.shared.ensureParakeetModel() }
        }
    }

    // MARK: - Parakeet Helpers
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

    func checkEnvReady() {
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
                } catch { ready = false }
            }
            await MainActor.run {
                envReady = ready
                isCheckingEnv = false
                if ready {
                    hasSetupParakeet = true
                    hasSetupLocalLLM = true
                }
            }
        }
    }

    private func venvPythonPath() -> String {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let base = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/bin/python3").path
        return base ?? ""
    }

    func verifyParakeetModel() {
        isVerifyingParakeet = true
        parakeetVerifyMessage = "Starting verification…"
        Task {
            do {
                let py = try await Task.detached(priority: .userInitiated) {
                    try UvBootstrap.ensureVenv(userPython: nil) { _ in }
                }.value
                let pythonPath = py.path
                await MainActor.run { parakeetVerifyMessage = "Checking model (offline)…" }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: pythonPath)

                var scriptURL = Bundle.main.url(forResource: "verify_parakeet", withExtension: "py")
                if scriptURL == nil {
                    let src = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/verify_parakeet.py")
                    if FileManager.default.fileExists(atPath: src.path) { scriptURL = src }
                }
                guard let scriptURL else { parakeetVerifyMessage = "Script not found"; isVerifyingParakeet = false; return }
                let repoToVerify = selectedParakeetModel.repoId
                process.arguments = [scriptURL.path, repoToVerify]
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
                                await MainActor.run { parakeetVerifyMessage = msg }
                            }
                        }
                    }
                }
                err.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await messageStore.updateStderr(trimmed)
                        await MainActor.run { parakeetVerifyMessage = trimmed }
                    }
                }

                try process.run()
                let timeoutTask = Task {
                    try await Task.sleep(for: .seconds(180))
                    if process.isRunning { process.terminate() }
                }
                await Task.detached { process.waitUntilExit() }.value
                timeoutTask.cancel()

                let lastStdoutMessage = await messageStore.stdoutMessage()
                let lastStderrMessage = await messageStore.stderrMessage()

                await MainActor.run {
                    isVerifyingParakeet = false
                    if process.terminationStatus == 0 {
                        parakeetVerifyMessage = (lastStdoutMessage.isEmpty ? "Model verified" : lastStdoutMessage)
                        hasSetupParakeet = true
                        Task { await MLXModelManager.shared.refreshModelList() }
                    } else {
                        let msg = lastStdoutMessage.isEmpty ? lastStderrMessage : lastStdoutMessage
                        parakeetVerifyMessage = msg.isEmpty ? "Verification failed" : "Verification failed: \(msg)"
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingParakeet = false
                    parakeetVerifyMessage = "Verification error: \(error.localizedDescription)"
                }
            }
        }
    }
}
