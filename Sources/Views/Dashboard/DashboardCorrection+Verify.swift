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

extension DashboardCorrectionView {
    // MARK: - Verify Row
    var verifyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if isVerifyingMLX { ProgressView().controlSize(.small) }
                Button(isVerifyingMLX ? "Verifying…" : "Verify MLX Model") {
                    verifyMLXModel()
                }
                .buttonStyle(.bordered)
                .tint(DashboardTheme.accent)
                .disabled(isVerifyingMLX)

                if let msg = mlxVerifyMessage,
                   !msg.isEmpty,
                   !msg.localizedCaseInsensitiveContains("fail"),
                   !msg.localizedCaseInsensitiveContains("error") {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(DashboardTheme.inkMuted)
                }
                Spacer()
            }

            // Surface verification failures via the shared DownloadProgressView
            // so users see a consistent failure UI with a Retry affordance.
            if let msg = mlxVerifyMessage,
               !msg.isEmpty,
               !isVerifyingMLX,
               msg.localizedCaseInsensitiveContains("fail")
                || msg.localizedCaseInsensitiveContains("error") {
                DownloadProgressView(
                    state: .failed(message: msg),
                    onRetry: { verifyMLXModel() }
                )
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers (copied from SettingsView)
    func runUvSetupSheet(title: String, onComplete: (() -> Void)? = nil) {
        setupStatus = title
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

    func venvPythonPath() -> String {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let base = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/bin/python3").path
        return base ?? ""
    }

    func verifyMLXModel() {
        isVerifyingMLX = true
        mlxVerifyMessage = "Checking model (offline)…"
        let repo = semanticCorrectionModelRepo
        Task {
            do {
                let py = try await UvBootstrap.ensureVenv(userPython: nil) { _ in }
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
                // Note: These handlers intentionally don't capture self or update @State directly
                // to avoid retain cycles. State is updated after process completion using messageStore.
                out.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    for line in s.split(separator: "\n").map(String.init) {
                        if let d = line.data(using: .utf8),
                           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                           let msg = j["message"] as? String {
                            Task {
                                await messageStore.updateStdout(msg)
                            }
                        }
                    }
                }
                err.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
                    let msg = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await messageStore.updateStderr(msg)
                    }
                }

                try process.run()
                let timeout = Task { try await Task.sleep(for: .seconds(180)); if process.isRunning { process.terminate() } }
                await Task.detached { process.waitUntilExit() }.value
                timeout.cancel()

                // Clean up file handle handlers to prevent leaks
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil

                let lastMsg = await messageStore.stdoutMessage()
                await MainActor.run {
                    isVerifyingMLX = false
                    if process.terminationStatus == 0 {
                        mlxVerifyMessage = lastMsg.isEmpty ? "Model verified" : lastMsg
                        Task { await modelManager.refreshModelList() }
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
}
