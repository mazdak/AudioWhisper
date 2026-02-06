import SwiftUI

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
        let repo = selectedParakeetModel.repoId
        let isDownloaded = mlxModelManager.downloadedModels.contains(repo)
        let isDownloading = mlxModelManager.isDownloading[repo] ?? false
        let progressText = mlxModelManager.downloadProgress[repo]

        Group {
            LabeledContent("Environment") {
                HStack(spacing: 10) {
                    if isCheckingEnv {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Label(envReady ? "Ready" : "Setup required",
                          systemImage: envReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(envReady ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))

                    if !envReady {
                        Button("Install…") {
                            runUvSetupSheet(title: "Installing Parakeet dependencies…")
                        }
                        .controlSize(.small)
                    } else {
                        Button(isVerifyingParakeet ? "Verifying…" : "Verify") {
                            verifyParakeetModel()
                        }
                        .disabled(isVerifyingParakeet)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LabeledContent("Model") {
                HStack(spacing: 10) {
                    Picker("", selection: $selectedParakeetModel) {
                        ForEach(ParakeetModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    if isDownloading {
                        ProgressView().controlSize(.small)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color(nsColor: .systemGreen))
                            .help("Downloaded")
                    } else {
                        Button("Get") { Task { await mlxModelManager.ensureParakeetModel() } }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let progressText, !progressText.isEmpty {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let msg = parakeetVerifyMessage, !msg.isEmpty {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Label("Runs locally on Apple Silicon • ~2.5 GB disk space", systemImage: "apple.logo")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onChange(of: selectedParakeetModel) { _, _ in
            Task { await mlxModelManager.ensureParakeetModel() }
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

                guard let scriptURL = ResourceLocator.pythonScriptURL(named: "verify_parakeet") else {
                    parakeetVerifyMessage = "Script not found"
                    isVerifyingParakeet = false
                    return
                }
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
