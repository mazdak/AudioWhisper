import SwiftUI

internal extension ContentView {
    func enhanceProgressMessage(_ message: String) -> String {
        return message
    }
    
    func updateStatus() {
        let modelDownloadMessage = currentModelDownloadMessage()
        statusViewModel.updateStatus(
            isRecording: audioRecorder.isRecording,
            isProcessing: isProcessing,
            modelDownloadMessage: modelDownloadMessage,
            progressMessage: progressMessage,
            hasPermission: audioRecorder.hasPermission,
            showSuccess: showSuccess,
            errorMessage: showError ? errorMessage : nil
        )
    }

    private func currentModelDownloadMessage() -> String? {
        guard audioRecorder.hasPermission else { return nil }
        guard transcriptionProvider == .local else { return nil }

        let model = selectedWhisperModel
        if WhisperKitStorage.isModelDownloaded(model) { return nil }

        if let stage = modelManager.downloadStages[model] {
            switch stage {
            case .preparing:
                return "Preparing \(model.displayName) model…"
            case .downloading:
                return "Downloading \(model.displayName) model…"
            case .processing:
                return "Processing \(model.displayName) model…"
            case .completing:
                return "Finalizing \(model.displayName) model…"
            case .ready:
                return nil
            case .failed:
                return "Model download failed — open Settings"
            }
        }

        if modelManager.downloadingModels.contains(model) {
            return "Downloading \(model.displayName) model…"
        }

        return "Model not downloaded — open Settings"
    }
    
    func recordSourceUsage(words: Int, characters: Int) {
        guard words > 0 else { return }
        let info = currentSourceAppInfo()
        SourceUsageStore.shared.recordUsage(for: info, words: words, characters: characters)
    }
    
    func currentSourceAppInfo() -> SourceAppInfo {
        if let cached = lastSourceAppInfo {
            return cached
        }
        
        if let stored = WindowController.storedTargetApp, let info = SourceAppInfo.from(app: stored) {
            lastSourceAppInfo = info
            return info
        }
        
        if let app = targetAppForPaste, let info = SourceAppInfo.from(app: app) {
            lastSourceAppInfo = info
            return info
        }
        
        if let fallback = findFallbackTargetApp(), let info = SourceAppInfo.from(app: fallback) {
            lastSourceAppInfo = info
            return info
        }
        
        return SourceAppInfo.unknown
    }
}
