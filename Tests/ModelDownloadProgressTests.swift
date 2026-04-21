import XCTest
@testable import AudioWhisper

// MARK: - DownloadFileProgress

final class DownloadFileProgressTests: XCTestCase {

    // MARK: displayText

    func testDisplayTextShowsPhaseTextWhenTotalFilesUnknown() {
        let progress = DownloadFileProgress(completedFiles: 0, totalFiles: nil, phase: .fetchingFileList)
        XCTAssertEqual(progress.displayText, DownloadFilePhase.fetchingFileList.displayText)
    }

    func testDisplayTextShowsFileCountWhenTotalFilesKnown() {
        let progress = DownloadFileProgress(completedFiles: 5, totalFiles: 47, phase: .coreML)
        XCTAssertEqual(progress.displayText, "5 / 47 files downloaded")
    }

    func testDisplayTextClampedWhenCompletedExceedsTotal() {
        // completedFiles can briefly exceed totalFiles during progress callbacks; displayText must not show that
        let progress = DownloadFileProgress(completedFiles: 50, totalFiles: 47, phase: .coreML)
        XCTAssertEqual(progress.displayText, "47 / 47 files downloaded")
    }

    func testDisplayTextAtZeroOfKnownTotal() {
        let progress = DownloadFileProgress(completedFiles: 0, totalFiles: 10, phase: .coreML)
        XCTAssertEqual(progress.displayText, "0 / 10 files downloaded")
    }

    // MARK: detailText

    func testDetailTextShowsErrorMessageWhenPresent() {
        let progress = DownloadFileProgress(
            completedFiles: 0, totalFiles: nil,
            phase: .failed,
            errorMessage: "Connection timed out"
        )
        XCTAssertEqual(progress.detailText, "Connection timed out")
    }

    func testDetailTextShowsPhaseAndFileNameWhenDownloading() {
        let progress = DownloadFileProgress(
            completedFiles: 3, totalFiles: 47,
            phase: .coreML,
            currentFileName: "AudioEncoder.mlmodelc"
        )
        XCTAssertEqual(progress.detailText, "\(DownloadFilePhase.coreML.displayText): AudioEncoder.mlmodelc")
    }

    func testDetailTextIsNilWhenNoFileName() {
        let progress = DownloadFileProgress(completedFiles: 0, totalFiles: nil, phase: .checkingFreeSpace)
        XCTAssertNil(progress.detailText)
    }

    func testErrorMessageTakesPrecedenceOverFileName() {
        let progress = DownloadFileProgress(
            completedFiles: 1, totalFiles: 10,
            phase: .failed,
            currentFileName: "some_file.bin",
            errorMessage: "HTTP 404"
        )
        XCTAssertEqual(progress.detailText, "HTTP 404")
    }
}

// MARK: - DownloadFilePhase

final class DownloadFilePhaseTests: XCTestCase {

    // MARK: displayText

    func testAllPhasesHaveNonEmptyDisplayText() {
        let phases: [DownloadFilePhase] = [
            .preparing, .creatingModelFolder, .checkingExistingModels,
            .checkingStorageLimit, .checkingFreeSpace, .fetchingFileList,
            .coreML, .supplemental, .verifying, .ready, .failed
        ]
        for phase in phases {
            XCTAssertFalse(phase.displayText.isEmpty, "displayText is empty for phase \(phase)")
        }
    }

    // MARK: downloadStage mapping

    func testPreparationPhasesMapToMatchingStages() {
        XCTAssertEqual(DownloadFilePhase.preparing.downloadStage, .preparing)
        XCTAssertEqual(DownloadFilePhase.creatingModelFolder.downloadStage, .creatingModelFolder)
        XCTAssertEqual(DownloadFilePhase.checkingExistingModels.downloadStage, .checkingExistingModels)
        XCTAssertEqual(DownloadFilePhase.checkingStorageLimit.downloadStage, .checkingStorageLimit)
        XCTAssertEqual(DownloadFilePhase.checkingFreeSpace.downloadStage, .checkingFreeSpace)
        XCTAssertEqual(DownloadFilePhase.fetchingFileList.downloadStage, .fetchingFileList)
    }

    func testDownloadPhasesMapToActiveStages() {
        XCTAssertEqual(DownloadFilePhase.coreML.downloadStage, .downloading)
        XCTAssertEqual(DownloadFilePhase.supplemental.downloadStage, .processing)
        XCTAssertEqual(DownloadFilePhase.verifying.downloadStage, .processing)
    }

    func testTerminalPhasesMapToCorrectStages() {
        XCTAssertEqual(DownloadFilePhase.ready.downloadStage, .ready)
        XCTAssertEqual(DownloadFilePhase.failed.downloadStage, .failed("Download failed"))
    }
}

// MARK: - DownloadStage (new cases)

final class DownloadStageNewCasesTests: XCTestCase {

    func testNewPreparationStagesAreActive() {
        let activePrepStages: [DownloadStage] = [
            .creatingModelFolder, .checkingExistingModels,
            .checkingStorageLimit, .checkingFreeSpace, .fetchingFileList
        ]
        for stage in activePrepStages {
            XCTAssertTrue(stage.isActive, "isActive should be true for \(stage)")
        }
    }

    func testNewPreparationStagesHaveDisplayText() {
        let stages: [DownloadStage] = [
            .creatingModelFolder, .checkingExistingModels,
            .checkingStorageLimit, .checkingFreeSpace, .fetchingFileList
        ]
        for stage in stages {
            XCTAssertFalse(stage.displayText.isEmpty, "displayText is empty for \(stage)")
        }
    }

    func testReadyAndFailedAreNotActive() {
        XCTAssertFalse(DownloadStage.ready.isActive)
        XCTAssertFalse(DownloadStage.failed("some error").isActive)
    }
}

// MARK: - ModelError

final class ModelErrorDescriptionTests: XCTestCase {

    func testDownloadFileFailedContainsFileName() {
        let error = ModelError.downloadFileFailed(
            fileName: "tokenizer.json",
            repo: "openai/whisper-base",
            reason: "HTTP 403"
        )
        let description = error.errorDescription ?? ""
        XCTAssertTrue(description.contains("tokenizer.json"), "Error description should mention the file name")
        XCTAssertTrue(description.contains("openai/whisper-base"), "Error description should mention the repo")
        XCTAssertTrue(description.contains("HTTP 403"), "Error description should mention the reason")
    }

    func testAlreadyDownloadingHasDescription() {
        let error = ModelError.alreadyDownloading
        XCTAssertFalse((error.errorDescription ?? "").isEmpty)
    }

    func testDownloadFailedHasDescription() {
        let error = ModelError.downloadFailed
        XCTAssertFalse((error.errorDescription ?? "").isEmpty)
    }
}

// MARK: - WhisperModel OpenAI repo

final class WhisperModelOpenAIRepoTests: XCTestCase {

    func testOpenAIWhisperRepoNames() {
        XCTAssertEqual(WhisperModel.tiny.openAIWhisperRepoName, "openai/whisper-tiny")
        XCTAssertEqual(WhisperModel.base.openAIWhisperRepoName, "openai/whisper-base")
        XCTAssertEqual(WhisperModel.small.openAIWhisperRepoName, "openai/whisper-small")
        XCTAssertEqual(WhisperModel.largeTurbo.openAIWhisperRepoName, "openai/whisper-large-v3-turbo")
    }

    func testOpenAIWhisperRepoURLsAreValid() {
        for model in WhisperModel.allCases {
            let url = model.openAIWhisperRepoURL
            XCTAssertEqual(url.scheme, "https", "URL scheme should be https for \(model)")
            XCTAssertEqual(url.host, "huggingface.co", "URL host should be huggingface.co for \(model)")
            XCTAssertTrue(url.path.hasPrefix("/openai/whisper-"), "URL path should start with /openai/whisper- for \(model)")
        }
    }

    func testOpenAIWhisperRepoURLMatchesRepoName() {
        for model in WhisperModel.allCases {
            let url = model.openAIWhisperRepoURL
            XCTAssertTrue(
                url.absoluteString.contains(model.openAIWhisperRepoName),
                "URL should contain repo name for \(model)"
            )
        }
    }
}
