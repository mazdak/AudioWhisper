import SwiftUI

internal extension ContentView {
    func enhanceProgressMessage(_ message: String) -> String {
        return message
    }

    func updateStatus() {
        viewModel.statusViewModel.updateStatus(
            isRecording: audioRecorder.isRecording,
            isProcessing: isProcessing,
            progressMessage: viewModel.progressMessage,
            hasPermission: permissionManager.microphonePermissionState == .granted,
            showSuccess: viewModel.showSuccess,
            errorMessage: viewModel.showError ? viewModel.errorMessage : nil
        )
    }

    func recordSourceUsage(words: Int, characters: Int) {
        guard words > 0 else { return }
        let info = currentSourceAppInfo()
        SourceUsageStore.shared.recordUsage(for: info, words: words, characters: characters)
    }

    func currentSourceAppInfo() -> SourceAppInfo {
        if let cached = viewModel.lastSourceAppInfo {
            return cached
        }

        if let stored = WindowController.storedTargetApp, let info = SourceAppInfo.from(app: stored) {
            viewModel.lastSourceAppInfo = info
            return info
        }

        if let app = viewModel.targetAppForPaste, let info = SourceAppInfo.from(app: app) {
            viewModel.lastSourceAppInfo = info
            return info
        }

        if let fallback = findFallbackTargetApp(), let info = SourceAppInfo.from(app: fallback) {
            viewModel.lastSourceAppInfo = info
            return info
        }

        return SourceAppInfo.unknown
    }
}
