import XCTest
import SwiftUI
import SwiftData
@testable import AudioWhisper

@MainActor
final class UISnapshotTests: SnapshotTestCase {
    private let defaults = UserDefaults.standard
    
    override func setUp() async throws {
        try await super.setUp()
        resetAppStorage()
    }
    
    override func tearDown() async throws {
        UsageMetricsStore.shared.reset()
        SourceUsageStore.shared.resetForTesting()
        try await super.tearDown()
    }
    
    func testWelcomeViewSnapshot() {
        defaults.set(TranscriptionProvider.local.rawValue, forKey: "transcriptionProvider")
        defaults.set(WhisperModel.base.rawValue, forKey: "selectedWhisperModel")
        
        let view = WelcomeView()
        assertSnapshot(
            view,
            named: "WelcomeView-light",
            size: LayoutMetrics.Welcome.windowSize,
            colorScheme: .light
        )
    }
    
    func testDashboardViewSnapshot() {
        seedUsageMetrics()
        seedSourceUsage()
        
        let view = DashboardView()
        assertSnapshot(
            view,
            named: "DashboardView-light",
            size: LayoutMetrics.DashboardWindow.previewSize,
            colorScheme: .light
        )
        
        UsageMetricsStore.shared.reset()
        SourceUsageStore.shared.resetForTesting()
    }
    
    func testTranscriptionHistoryViewSnapshot() throws {
        let container = try makePreviewContainer()
        let view = TranscriptionHistoryView()
            .modelContainer(container)
        
        assertSnapshot(
            view,
            named: "TranscriptionHistoryView-dark",
            size: LayoutMetrics.TranscriptionHistory.previewSize,
            colorScheme: .dark
        )
    }
}

// MARK: - Helpers
private extension UISnapshotTests {
    func resetAppStorage() {
        let keys = [
            "transcriptionProvider",
            "selectedWhisperModel",
            "selectedParakeetModel",
            "hasSetupParakeet",
            "hasSetupLocalLLM",
            "openAIBaseURL",
            "geminiBaseURL",
            "maxModelStorageGB",
            "globalHotkey",
            "pressAndHoldEnabled",
            "pressAndHoldKeyIdentifier",
            "pressAndHoldMode",
            "selectedMicrophone",
            "transcriptionHistoryEnabled"
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
    
    func seedUsageMetrics() {
        let snapshot = UsageSnapshot(
            totalSessions: 8,
            totalDuration: 540,
            totalWords: 2750,
            totalCharacters: 13800,
            lastUpdated: ISO8601DateFormatter().date(from: "2025-12-10T12:00:00Z"),
            dailyActivity: [
                "2025-12-10": 500,
                "2025-12-09": 450,
                "2025-12-08": 600,
                "2025-12-07": 400,
                "2025-12-06": 300,
                "2025-12-05": 500
            ]
        )
        UsageMetricsStore.shared.setSnapshotForTesting(snapshot)
    }
    
    func seedSourceUsage() {
        let store = SourceUsageStore.shared
        store.resetForTesting()
        
        let sources = [
            SourceAppInfo(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit", iconData: nil, fallbackSymbolName: "doc.text"),
            SourceAppInfo(bundleIdentifier: "com.apple.Safari", displayName: "Safari", iconData: nil, fallbackSymbolName: "safari.fill"),
            SourceAppInfo(bundleIdentifier: "com.slack.slackmacgap", displayName: "Slack", iconData: nil, fallbackSymbolName: "bubble.left.and.bubble.right.fill")
        ]
        
        store.recordUsage(for: sources[0], words: 1200, characters: 6000)
        store.recordUsage(for: sources[1], words: 800, characters: 4100)
        store.recordUsage(for: sources[2], words: 650, characters: 3400)
    }
    
    func makePreviewContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        
        let sampleRecords = [
            TranscriptionRecord(
                text: "This is a sample transcription from OpenAI Whisper service. It demonstrates how the history view will look with longer text content.",
                provider: .openai,
                duration: 12.5,
                modelUsed: "large-v3"
            ),
            TranscriptionRecord(
                text: "Meeting notes about upcoming launch. Includes key dates and action items.",
                provider: .gemini,
                duration: 8.3,
                modelUsed: "gemini-pro"
            ),
            TranscriptionRecord(
                text: "Quick local test recording to verify offline pipeline works correctly.",
                provider: .local,
                duration: 4.2,
                modelUsed: "base"
            )
        ]
        
        for record in sampleRecords {
            context.insert(record)
        }
        try context.save()
        return container
    }
}
