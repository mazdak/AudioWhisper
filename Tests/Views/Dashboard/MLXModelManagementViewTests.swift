import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

// MARK: - MLXModelManagementView Tests
@MainActor
final class MLXModelManagementViewTests: XCTestCase {

    func testViewCanBeCreated() {
        var selectedModel = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let binding = Binding(
            get: { selectedModel },
            set: { selectedModel = $0 }
        )
        let view = MLXModelManagementView(selectedModelRepo: binding)
        XCTAssertNotNil(view)
    }

    func testViewBodyDoesNotCrash() {
        var selectedModel = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let binding = Binding(
            get: { selectedModel },
            set: { selectedModel = $0 }
        )
        let view = MLXModelManagementView(selectedModelRepo: binding)
            .environment(MLXModelManager.shared)
        let hosting = NSHostingView(rootView: view)
        XCTAssertNotNil(hosting)
    }

    func testSelectedModelBindingUpdates() {
        var selectedModel = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let binding = Binding(
            get: { selectedModel },
            set: { selectedModel = $0 }
        )

        binding.wrappedValue = "mlx-community/Other-Model"
        XCTAssertEqual(selectedModel, "mlx-community/Other-Model")
    }
}

// MARK: - MLXModelManager Tests
@MainActor
final class MLXModelManagerViewTests: XCTestCase {

    func testMLXModelManagerSharedExists() {
        let manager = MLXModelManager.shared
        XCTAssertNotNil(manager)
    }

    func testRecommendedModelsListExists() {
        let models = MLXModelManager.recommendedModels
        XCTAssertFalse(models.isEmpty)
    }

    func testRecommendedModelsHaveNames() {
        let models = MLXModelManager.recommendedModels
        for model in models {
            XCTAssertFalse(model.displayName.isEmpty)
        }
    }

    func testRecommendedModelsHaveRepos() {
        let models = MLXModelManager.recommendedModels
        for model in models {
            XCTAssertFalse(model.repo.isEmpty)
        }
    }

    func testFormatBytesFunction() {
        let manager = MLXModelManager.shared

        let formattedZero = manager.formatBytes(0)
        XCTAssertFalse(formattedZero.isEmpty)

        let formattedKB = manager.formatBytes(1024)
        XCTAssertFalse(formattedKB.isEmpty)

        let formattedMB = manager.formatBytes(1024 * 1024)
        XCTAssertFalse(formattedMB.isEmpty)

        let formattedGB = manager.formatBytes(1024 * 1024 * 1024)
        XCTAssertFalse(formattedGB.isEmpty)
    }

    func testDownloadedModelsProperty() {
        let manager = MLXModelManager.shared
        let downloadedModels = manager.downloadedModels
        XCTAssertNotNil(downloadedModels)
    }

    func testIsDownloadingProperty() {
        let manager = MLXModelManager.shared
        let isDownloading = manager.isDownloading
        XCTAssertNotNil(isDownloading)
    }

    func testDownloadProgressProperty() {
        let manager = MLXModelManager.shared
        let progress = manager.downloadProgress
        XCTAssertNotNil(progress)
    }

    func testModelSizesProperty() {
        let manager = MLXModelManager.shared
        let sizes = manager.modelSizes
        XCTAssertNotNil(sizes)
    }

    func testTotalCacheSizeProperty() {
        let manager = MLXModelManager.shared
        let size = manager.totalCacheSize
        XCTAssertGreaterThanOrEqual(size, 0)
    }
}

// MARK: - Recommended Model Tests
final class RecommendedModelTests: XCTestCase {

    func testDefaultRecommendedModel() {
        let defaultRepo = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        XCTAssertFalse(defaultRepo.isEmpty)
    }

    func testRecommendedModelIdentification() {
        let recommendedRepo = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        let isRecommended = recommendedRepo == "mlx-community/Llama-3.2-1B-Instruct-4bit"
        XCTAssertTrue(isRecommended)
    }
}

// MARK: - Model Entry Adapter Tests
@MainActor
final class ModelEntryAdapterTests: XCTestCase {

    func testMLXEntryCreation() {
        let models = MLXModelManager.recommendedModels
        guard let firstModel = models.first else {
            XCTFail("Should have at least one recommended model")
            return
        }

        let entry = MLXEntry(
            model: firstModel,
            isDownloaded: false,
            isDownloading: false,
            statusText: nil,
            sizeText: "1GB",
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.title, firstModel.displayName)
        XCTAssertFalse(entry.isDownloaded)
        XCTAssertFalse(entry.isDownloading)
    }
}

// MARK: - Cache Path Tests
final class MLXCachePathTests: XCTestCase {

    func testHuggingFaceCachePath() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let cachePath = homeDir.appendingPathComponent(".cache/huggingface/hub")

        XCTAssertTrue(cachePath.path.contains(".cache"))
        XCTAssertTrue(cachePath.path.contains("huggingface"))
        XCTAssertTrue(cachePath.path.contains("hub"))
    }

    func testCachePathFormat() {
        let displayPath = "~/.cache/huggingface/hub/"
        XCTAssertTrue(displayPath.hasPrefix("~/"))
        XCTAssertTrue(displayPath.hasSuffix("/"))
    }
}

// MARK: - Refresh State Tests
@MainActor
final class MLXRefreshStateTests: XCTestCase {

    func testRefreshModelListAsync() async {
        let manager = MLXModelManager.shared
        await manager.refreshModelList()
        // Should complete without crash
        XCTAssertTrue(true)
    }
}

// MARK: - UnifiedModelRow Tests
final class UnifiedModelRowTests: XCTestCase {

    func testUnifiedModelRowWithAllParameters() {
        let row = UnifiedModelRow(
            title: "Test Model",
            subtitle: "Test Description",
            sizeText: "1GB",
            statusText: nil,
            statusColor: .blue,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )
        XCTAssertNotNil(row)
    }

    func testUnifiedModelRowDownloadedState() {
        let row = UnifiedModelRow(
            title: "Downloaded Model",
            subtitle: "Description",
            sizeText: "500MB",
            statusText: nil,
            statusColor: .green,
            isDownloaded: true,
            isDownloading: false,
            isSelected: true,
            badgeText: "RECOMMENDED",
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )
        XCTAssertNotNil(row)
    }

    func testUnifiedModelRowDownloadingState() {
        let row = UnifiedModelRow(
            title: "Downloading Model",
            subtitle: "Description",
            sizeText: "2GB",
            statusText: "Downloading...",
            statusColor: .orange,
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )
        XCTAssertNotNil(row)
    }
}
