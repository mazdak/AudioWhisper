import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - LocalWhisperEntry Tests
final class LocalWhisperEntryTests: XCTestCase {

    func testLocalWhisperEntryCreation() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.title, WhisperModel.base.displayName)
        XCTAssertFalse(entry.isDownloaded)
        XCTAssertFalse(entry.isDownloading)
        XCTAssertFalse(entry.isSelected)
    }

    func testLocalWhisperEntryTitle() {
        for model in WhisperModel.allCases {
            let entry = LocalWhisperEntry(
                model: model,
                stage: nil,
                estimatedTimeRemaining: nil,
                isDownloaded: false,
                isDownloading: false,
                isSelected: false,
                onSelect: {},
                onDownload: {},
                onDelete: {}
            )

            XCTAssertEqual(entry.title, model.displayName)
        }
    }

    func testLocalWhisperEntrySubtitle() {
        let entry = LocalWhisperEntry(
            model: .tiny,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.subtitle, WhisperModel.tiny.description)
    }

    func testLocalWhisperEntrySizeText() {
        let entry = LocalWhisperEntry(
            model: .small,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.sizeText, WhisperModel.small.fileSize)
    }

    func testLocalWhisperEntryStatusTextWithNoStage() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertNil(entry.statusText)
    }

    func testLocalWhisperEntryStatusTextWithStage() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .downloading,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertNotNil(entry.statusText)
        XCTAssertTrue(entry.statusText?.contains(DownloadStage.downloading.displayText) ?? false)
    }

    func testLocalWhisperEntryStatusTextWithTimeRemaining() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .downloading,
            estimatedTimeRemaining: 65, // 1 minute 5 seconds
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertNotNil(entry.statusText)
        XCTAssertTrue(entry.statusText?.contains("1m") ?? false)
        XCTAssertTrue(entry.statusText?.contains("5s") ?? false)
    }

    func testLocalWhisperEntryStatusTextWithSecondsOnly() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .downloading,
            estimatedTimeRemaining: 30,
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertNotNil(entry.statusText)
        XCTAssertTrue(entry.statusText?.contains("30s") ?? false)
        XCTAssertFalse(entry.statusText?.contains("m") ?? true)
    }

    func testLocalWhisperEntryStatusColorForFailed() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .failed,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .red)
    }

    func testLocalWhisperEntryStatusColorForDownloading() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .downloading,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: true,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .blue)
    }

    func testLocalWhisperEntryStatusColorForReady() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: .ready,
            estimatedTimeRemaining: nil,
            isDownloaded: true,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .green)
    }

    func testLocalWhisperEntryBadgeTextForBase() {
        let entry = LocalWhisperEntry(
            model: .base,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.badgeText, "RECOMMENDED")
    }

    func testLocalWhisperEntryBadgeTextForNonBase() {
        for model in WhisperModel.allCases where model != .base {
            let entry = LocalWhisperEntry(
                model: model,
                stage: nil,
                estimatedTimeRemaining: nil,
                isDownloaded: false,
                isDownloading: false,
                isSelected: false,
                onSelect: {},
                onDownload: {},
                onDelete: {}
            )

            XCTAssertNil(entry.badgeText)
        }
    }
}

// MARK: - MLXEntry Tests
final class MLXEntryTests: XCTestCase {

    func testMLXEntryCreation() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
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

        XCTAssertEqual(entry.title, model.displayName)
        XCTAssertEqual(entry.subtitle, model.description)
        XCTAssertFalse(entry.isDownloaded)
        XCTAssertFalse(entry.isDownloading)
    }

    func testMLXEntryTitle() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
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

        XCTAssertEqual(entry.title, model.name)
    }

    func testMLXEntryStatusColorForError() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: false,
            statusText: "Error: Download failed",
            sizeText: "1GB",
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .red)
    }

    func testMLXEntryStatusColorForPlease() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: false,
            statusText: "Please check your connection",
            sizeText: "1GB",
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .red)
    }

    func testMLXEntryStatusColorForDownloading() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: true,
            statusText: "Downloading...",
            sizeText: "1GB",
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .blue)
    }

    func testMLXEntryStatusColorForNormal() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
            isDownloaded: true,
            isDownloading: false,
            statusText: nil,
            sizeText: "1GB",
            isSelected: true,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertNil(entry.statusColor)
    }

    func testMLXEntryCaseInsensitiveErrorDetection() {
        let model = MLXModelManager.recommendedModels.first!
        let entry = MLXEntry(
            model: model,
            isDownloaded: false,
            isDownloading: false,
            statusText: "ERROR: Something went wrong",
            sizeText: "1GB",
            isSelected: false,
            badgeText: nil,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertEqual(entry.statusColor, .red)
    }
}

// MARK: - ModelEntry Protocol Tests
final class ModelEntryProtocolTests: XCTestCase {

    func testLocalWhisperEntryConformsToModelEntry() {
        let entry: ModelEntry = LocalWhisperEntry(
            model: .base,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: {},
            onDownload: {},
            onDelete: {}
        )

        XCTAssertFalse(entry.title.isEmpty)
        XCTAssertFalse(entry.subtitle.isEmpty)
    }

    func testMLXEntryConformsToModelEntry() {
        let model = MLXModelManager.recommendedModels.first!
        let entry: ModelEntry = MLXEntry(
            model: model,
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

        XCTAssertFalse(entry.title.isEmpty)
        XCTAssertFalse(entry.subtitle.isEmpty)
    }

    func testModelEntryCallbacks() {
        var selectCalled = false
        var downloadCalled = false
        var deleteCalled = false

        let entry = LocalWhisperEntry(
            model: .base,
            stage: nil,
            estimatedTimeRemaining: nil,
            isDownloaded: false,
            isDownloading: false,
            isSelected: false,
            onSelect: { selectCalled = true },
            onDownload: { downloadCalled = true },
            onDelete: { deleteCalled = true }
        )

        entry.onSelect()
        entry.onDownload()
        entry.onDelete()

        XCTAssertTrue(selectCalled)
        XCTAssertTrue(downloadCalled)
        XCTAssertTrue(deleteCalled)
    }
}
