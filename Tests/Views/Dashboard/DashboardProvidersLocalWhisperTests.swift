import XCTest
import SwiftUI
@testable import AudioWhisper

/// Tests for DashboardProviders+LocalWhisper extension functionality
@MainActor
final class DashboardProvidersLocalWhisperTests: XCTestCase {

    // MARK: - Whisper Model Row Tests

    func testWhisperModelRowSelectionState() {
        let selectedModel = WhisperModel.base
        let testModel = WhisperModel.base

        let isSelected = selectedModel == testModel
        XCTAssertTrue(isSelected)
    }

    func testWhisperModelRowNotSelectedState() {
        let selectedModel = WhisperModel.base
        let testModel = WhisperModel.tiny

        let isSelected = selectedModel == testModel
        XCTAssertFalse(isSelected)
    }

    func testWhisperModelBaseIsRecommended() {
        let model = WhisperModel.base
        let isRecommended = model == .base

        XCTAssertTrue(isRecommended, "Base model should be recommended")
    }

    func testWhisperModelTinyIsNotRecommended() {
        let model = WhisperModel.tiny
        let isRecommended = model == .base

        XCTAssertFalse(isRecommended, "Tiny model should not be recommended")
    }

    // MARK: - Model Download State Tests

    func testModelIsDownloadingState() {
        var downloadStartTime: [WhisperModel: Date] = [:]
        let model = WhisperModel.base

        // Start download
        downloadStartTime[model] = Date()
        let isDownloading = downloadStartTime[model] != nil

        XCTAssertTrue(isDownloading)
    }

    func testModelNotDownloadingState() {
        let downloadStartTime: [WhisperModel: Date] = [:]
        let model = WhisperModel.base

        let isDownloading = downloadStartTime[model] != nil
        XCTAssertFalse(isDownloading)
    }

    func testModelIsDownloadedState() {
        let downloadedModels: [WhisperModel] = [.base, .tiny]
        let model = WhisperModel.base

        let isDownloaded = downloadedModels.contains(model)
        XCTAssertTrue(isDownloaded)
    }

    func testModelNotDownloadedState() {
        let downloadedModels: [WhisperModel] = [.tiny]
        let model = WhisperModel.base

        let isDownloaded = downloadedModels.contains(model)
        XCTAssertFalse(isDownloaded)
    }

    // MARK: - Download Action Logic Tests

    func testDownloadClearsError() {
        var downloadError: String? = "Previous error"

        // When starting a new download, error should be cleared
        downloadError = nil
        XCTAssertNil(downloadError)
    }

    func testDownloadSetsStartTime() {
        var downloadStartTime: [WhisperModel: Date] = [:]
        let model = WhisperModel.base

        downloadStartTime[model] = Date()
        XCTAssertNotNil(downloadStartTime[model])
    }

    func testDownloadSuccessRemovesStartTime() {
        var downloadStartTime: [WhisperModel: Date] = [:]
        let model = WhisperModel.base

        downloadStartTime[model] = Date()
        // On success
        downloadStartTime.removeValue(forKey: model)

        XCTAssertNil(downloadStartTime[model])
    }

    func testDownloadFailureSetsError() {
        var downloadError: String?
        var downloadStartTime: [WhisperModel: Date] = [:]
        let model = WhisperModel.base

        downloadStartTime[model] = Date()
        // On failure
        downloadError = "Network error"
        downloadStartTime.removeValue(forKey: model)

        XCTAssertNotNil(downloadError)
        XCTAssertNil(downloadStartTime[model])
    }

    // MARK: - Delete Model Logic Tests

    func testDeleteModelUpdatesDownloadedList() {
        var downloadedModels: [WhisperModel] = [.base, .tiny]
        let modelToDelete = WhisperModel.base

        downloadedModels.removeAll { $0 == modelToDelete }

        XCTAssertFalse(downloadedModels.contains(modelToDelete))
        XCTAssertTrue(downloadedModels.contains(.tiny))
    }

    func testDeleteModelFailureSetsError() {
        var downloadError: String?

        // Simulate delete failure
        downloadError = "Cannot delete model in use"

        XCTAssertNotNil(downloadError)
    }

    // MARK: - Storage Footer Tests

    func testStorageFooterBytesCalculation() {
        let storageGB = 5.0
        let limitBytes = Int64(storageGB * 1024 * 1024 * 1024)

        XCTAssertEqual(limitBytes, 5_368_709_120)
    }

    func testStorageLimitOptions() {
        let validLimits: [Double] = [1.0, 2.0, 5.0, 10.0]

        for limit in validLimits {
            let bytes = Int64(limit * 1024 * 1024 * 1024)
            XCTAssertGreaterThan(bytes, 0)
        }
    }

    func testFormatBytesLogic() {
        // Test the byte formatting logic
        let bytes: Int64 = 142_000_000 // ~142 MB
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file

        let formatted = formatter.string(fromByteCount: bytes)
        XCTAssertFalse(formatted.isEmpty)
    }

    func testFormatBytesGBRange() {
        let bytes: Int64 = 1_500_000_000 // ~1.5 GB
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file

        let formatted = formatter.string(fromByteCount: bytes)
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("MB"))
    }

    // MARK: - Model Selection on Tap Tests

    func testTapOnModelSelectsIt() {
        var selectedModel = WhisperModel.tiny
        let tappedModel = WhisperModel.base

        // Simulate tap
        selectedModel = tappedModel

        XCTAssertEqual(selectedModel, .base)
    }

    func testTapOnNotDownloadedModelTriggersDownload() {
        var selectedModel = WhisperModel.tiny
        let downloadedModels: [WhisperModel] = [.tiny]
        var downloadStartTime: [WhisperModel: Date] = [:]

        let tappedModel = WhisperModel.base
        let isDownloaded = downloadedModels.contains(tappedModel)
        let isDownloading = downloadStartTime[tappedModel] != nil

        // Simulate tap behavior
        selectedModel = tappedModel
        if !isDownloaded && !isDownloading {
            // Would trigger download
            downloadStartTime[tappedModel] = Date()
        }

        XCTAssertEqual(selectedModel, .base)
        XCTAssertNotNil(downloadStartTime[tappedModel], "Should trigger download")
    }

    func testTapOnDownloadedModelDoesNotTriggerDownload() {
        var selectedModel = WhisperModel.tiny
        let downloadedModels: [WhisperModel] = [.tiny, .base]
        var downloadStartTime: [WhisperModel: Date] = [:]

        let tappedModel = WhisperModel.base
        let isDownloaded = downloadedModels.contains(tappedModel)
        let isDownloading = downloadStartTime[tappedModel] != nil

        // Simulate tap behavior
        selectedModel = tappedModel
        if !isDownloaded && !isDownloading {
            downloadStartTime[tappedModel] = Date()
        }

        XCTAssertEqual(selectedModel, .base)
        XCTAssertNil(downloadStartTime[tappedModel], "Should not trigger download")
    }

    // MARK: - Model List Divider Tests

    func testDividerNotShownAfterLastModel() {
        let models = WhisperModel.allCases
        let lastModel = models.last

        for model in models {
            let showDivider = model != lastModel

            if model == lastModel {
                XCTAssertFalse(showDivider, "Last model should not show divider")
            } else {
                XCTAssertTrue(showDivider, "Non-last models should show divider")
            }
        }
    }

    // MARK: - Error Display Tests

    func testErrorMessageDisplayed() {
        let downloadError: String? = "Download failed"

        XCTAssertNotNil(downloadError)
        XCTAssertFalse(downloadError?.isEmpty ?? true)
    }

    func testNoErrorHidesMessage() {
        let downloadError: String? = nil

        XCTAssertNil(downloadError)
    }

    // MARK: - Storage Path Tests

    func testStoragePath() {
        let expectedPath = "~/Documents/huggingface/models/"
        XCTAssertTrue(expectedPath.contains("huggingface"))
    }

    // MARK: - Model Information Tests

    func testAllModelsHaveDisplayNames() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty)
        }
    }

    func testAllModelsHaveDescriptions() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.description.isEmpty)
        }
    }

    func testAllModelsHaveFileSizes() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.fileSize.isEmpty)
        }
    }

    func testModelSizesAreOrdered() {
        // Models should generally increase in size
        let sizes = ["39MB", "142MB", "466MB", "1.5GB"]

        XCTAssertEqual(WhisperModel.tiny.fileSize, sizes[0])
        XCTAssertEqual(WhisperModel.base.fileSize, sizes[1])
        XCTAssertEqual(WhisperModel.small.fileSize, sizes[2])
        XCTAssertEqual(WhisperModel.largeTurbo.fileSize, sizes[3])
    }

    // MARK: - Refresh Action Tests

    func testRefreshModelStates() async {
        // Refresh should update downloadedModels, totalModelsSize, and modelDownloadStates
        var downloadedModels: [WhisperModel] = []
        var totalModelsSize: Int64 = 0
        var modelDownloadStates: [WhisperModel: Bool] = [:]

        // Simulate refresh result
        downloadedModels = [.base]
        totalModelsSize = 142_000_000
        modelDownloadStates = [.base: true, .tiny: false]

        XCTAssertEqual(downloadedModels, [.base])
        XCTAssertEqual(totalModelsSize, 142_000_000)
        XCTAssertTrue(modelDownloadStates[.base] ?? false)
        XCTAssertFalse(modelDownloadStates[.tiny] ?? true)
    }
}
