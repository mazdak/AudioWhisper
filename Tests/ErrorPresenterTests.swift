import XCTest
@testable import AudioWhisper

@MainActor
final class ErrorPresenterTests: XCTestCase {
    @MainActor override func setUp() {
        super.setUp()
        ErrorPresenter.shared.isTestEnvironment = true
    }

    // MARK: - Retry Notifications

    @MainActor func testConnectionErrorPostsRetryRequested() {
        let expectation = expectation(forNotification: .retryRequested, object: nil, handler: nil)

        ErrorPresenter.shared.showError("Internet connection dropped. Please try again.")

        wait(for: [expectation], timeout: 1.0)
    }

    @MainActor func testTranscriptionErrorPostsRetryTranscriptionRequested() {
        let expectation = expectation(forNotification: .retryTranscriptionRequested, object: nil, handler: nil)

        ErrorPresenter.shared.showError("Transcription failed for the audio file")

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Unknown Error Handling

    @MainActor func testUnknownErrorDoesNotPostRetryNotifications() {
        let retryExpectation = expectation(forNotification: .retryRequested, object: nil, handler: nil)
        retryExpectation.isInverted = true

        let transcriptionExpectation = expectation(forNotification: .retryTranscriptionRequested, object: nil, handler: nil)
        transcriptionExpectation.isInverted = true

        ErrorPresenter.shared.showError("An unexpected error occurred")

        wait(for: [retryExpectation, transcriptionExpectation], timeout: 1.0)
    }
}
