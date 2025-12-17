import SwiftUI

internal extension ContentView {
    func enhanceProgressMessage(_ message: String) -> String {
        return message
    }
    
    func updateStatus() {
        statusViewModel.updateStatus(
            isRecording: audioRecorder.isRecording,
            isProcessing: isProcessing,
            progressMessage: progressMessage,
            hasPermission: audioRecorder.hasPermission,
            showSuccess: showSuccess,
            errorMessage: showError ? errorMessage : nil
        )
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
