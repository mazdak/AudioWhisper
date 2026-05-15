import SwiftUI
import AppKit

internal struct DashboardCorrectionView: View {
    // Stored preferences
    @AppStorage("semanticCorrectionMode") var semanticCorrectionModeRaw = SemanticCorrectionMode.off.rawValue
    @AppStorage("semanticCorrectionModelRepo") var semanticCorrectionModelRepo = "mlx-community/Qwen3-1.7B-4bit"
    @AppStorage("hasSetupLocalLLM") var hasSetupLocalLLM = false
    @AppStorage("hasSetupParakeet") var hasSetupParakeet = false

    // Model management
    @State var modelManager = MLXModelManager.shared

    // Environment + verification state
    @State var envReady = false
    @State var isCheckingEnv = false
    @State var isSettingUp = false
    @State var showSetupSheet = false
    @State var setupStatus: String?
    @State var setupLogs = ""
    @State var isVerifyingMLX = false
    @State var mlxVerifyMessage: String?

    @State var isRefreshingModels = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Semantic Correction")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DashboardTheme.ink)

                modeSelectorSection

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
}

// MARK: - Testable Helpers
extension DashboardCorrectionView {
    /// Returns the semantic correction mode from raw string
    static func testableParseMode(from rawValue: String) -> SemanticCorrectionMode? {
        SemanticCorrectionMode(rawValue: rawValue)
    }

    /// Returns the view type that should be displayed for a given mode
    static func testableViewTypeForMode(_ modeRaw: String) -> String {
        let mode = SemanticCorrectionMode(rawValue: modeRaw) ?? .off
        switch mode {
        case .off:
            return "disabled_info"
        case .localMLX:
            return "local_mlx_card"
        }
    }

    /// Returns whether install button should be shown
    static func testableShowsInstallButton(envReady: Bool) -> Bool {
        !envReady
    }

    /// Returns whether model list should be shown
    static func testableShowsModelList(envReady: Bool) -> Bool {
        envReady
    }

    /// Returns the default model repo for fallback
    static func testableDefaultModelRepo() -> String {
        "mlx-community/Qwen3-1.7B-4bit"
    }

    /// Creates a mock model entry for testing
    static func testableMakeMLXEntry(
        model: MLXModel,
        isDownloaded: Bool,
        isDownloading: Bool,
        isSelected: Bool,
        badgeText: String?
    ) -> (title: String, subtitle: String, isDownloaded: Bool, isDownloading: Bool, isSelected: Bool, badgeText: String?) {
        (
            title: model.displayName,
            subtitle: model.description,
            isDownloaded: isDownloaded,
            isDownloading: isDownloading,
            isSelected: isSelected,
            badgeText: badgeText
        )
    }

    /// Returns whether a model should have the "RECOMMENDED" badge
    static func testableIsRecommended(repo: String) -> Bool {
        repo == "mlx-community/Qwen3-1.7B-4bit"
    }

    /// Returns the venv Python path for testing
    static func testableVenvPythonPath() -> String {
        let appSupport = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        let base = appSupport?.appendingPathComponent("AudioWhisper/python_project/.venv/bin/python3").path
        return base ?? ""
    }

    /// Verification timeout value in seconds
    static var testableVerificationTimeout: Int {
        180
    }
}
