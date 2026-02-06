import XCTest
import SwiftUI
@testable import AudioWhisper

final class AppStatusTests: XCTestCase {
    
    // MARK: - AppStatus Tests
    
    func testAppStatusMessages() {
        XCTAssertEqual(AppStatus.error("Test error").message, "Test error")
        XCTAssertEqual(AppStatus.recording.message, "Recording...")
        XCTAssertEqual(AppStatus.processing("Converting...").message, "Converting...")
        XCTAssertEqual(AppStatus.downloadingModel("Downloading Base…").message, "Downloading Base…")
        XCTAssertEqual(AppStatus.success.message, "Success!")
        XCTAssertEqual(AppStatus.ready.message, "Ready")
        XCTAssertEqual(AppStatus.permissionRequired.message, "Microphone access required")
    }
    
    func testAppStatusColors() {
        XCTAssertEqual(AppStatus.error("Test").color, .red)
        XCTAssertEqual(AppStatus.recording.color, .red)
        XCTAssertEqual(AppStatus.processing("Test").color, .orange)
        XCTAssertEqual(AppStatus.downloadingModel("Test").color, .orange)
        XCTAssertEqual(AppStatus.success.color, .green)
        XCTAssertEqual(AppStatus.ready.color, .blue)
        XCTAssertEqual(AppStatus.permissionRequired.color, .gray)
    }
    
    func testAppStatusIcons() {
        XCTAssertEqual(AppStatus.error("Test").icon, "exclamationmark.triangle.fill")
        XCTAssertNil(AppStatus.recording.icon)
        XCTAssertNil(AppStatus.processing("Test").icon)
        XCTAssertNil(AppStatus.downloadingModel("Test").icon)
        XCTAssertEqual(AppStatus.success.icon, "checkmark.circle.fill")
        XCTAssertNil(AppStatus.ready.icon)
        XCTAssertEqual(AppStatus.permissionRequired.icon, "mic.slash.fill")
    }
    
    func testAppStatusShouldAnimate() {
        XCTAssertFalse(AppStatus.error("Test").shouldAnimate)
        XCTAssertTrue(AppStatus.recording.shouldAnimate)
        XCTAssertTrue(AppStatus.processing("Test").shouldAnimate)
        XCTAssertTrue(AppStatus.downloadingModel("Test").shouldAnimate)
        XCTAssertFalse(AppStatus.success.shouldAnimate)
        XCTAssertFalse(AppStatus.ready.shouldAnimate)
        XCTAssertFalse(AppStatus.permissionRequired.shouldAnimate)
    }
    
    func testAppStatusShowInfoButton() {
        XCTAssertFalse(AppStatus.error("Test").showInfoButton)
        XCTAssertFalse(AppStatus.recording.showInfoButton)
        XCTAssertFalse(AppStatus.processing("Test").showInfoButton)
        XCTAssertFalse(AppStatus.downloadingModel("Test").showInfoButton)
        XCTAssertFalse(AppStatus.success.showInfoButton)
        XCTAssertFalse(AppStatus.ready.showInfoButton)
        XCTAssertTrue(AppStatus.permissionRequired.showInfoButton)
    }
    
    func testAppStatusEquality() {
        XCTAssertEqual(AppStatus.ready, AppStatus.ready)
        XCTAssertEqual(AppStatus.recording, AppStatus.recording)
        XCTAssertEqual(AppStatus.success, AppStatus.success)
        XCTAssertEqual(AppStatus.permissionRequired, AppStatus.permissionRequired)
        XCTAssertEqual(AppStatus.error("Test"), AppStatus.error("Test"))
        XCTAssertEqual(AppStatus.processing("Test"), AppStatus.processing("Test"))
        XCTAssertEqual(AppStatus.downloadingModel("Test"), AppStatus.downloadingModel("Test"))
        
        XCTAssertNotEqual(AppStatus.ready, AppStatus.recording)
        XCTAssertNotEqual(AppStatus.error("Test1"), AppStatus.error("Test2"))
        XCTAssertNotEqual(AppStatus.processing("Test1"), AppStatus.processing("Test2"))
        XCTAssertNotEqual(AppStatus.downloadingModel("Test1"), AppStatus.downloadingModel("Test2"))
    }
    
    // MARK: - StatusViewModel Tests
    
    func testStatusViewModelInitialState() {
        let viewModel = StatusViewModel()
        XCTAssertEqual(viewModel.currentStatus, .ready)
    }
    
    func testStatusViewModelUpdateWithError() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: false,
            modelDownloadMessage: nil,
            progressMessage: "",
            hasPermission: true,
            showSuccess: false,
            errorMessage: "Test error"
        )
        
        XCTAssertEqual(viewModel.currentStatus, .error("Test error"))
    }
    
    func testStatusViewModelUpdateWithSuccess() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: false,
            modelDownloadMessage: nil,
            progressMessage: "",
            hasPermission: true,
            showSuccess: true
        )
        
        XCTAssertEqual(viewModel.currentStatus, .success)
    }
    
    func testStatusViewModelUpdateWithRecording() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: true,
            isProcessing: false,
            modelDownloadMessage: nil,
            progressMessage: "",
            hasPermission: true,
            showSuccess: false
        )
        
        XCTAssertEqual(viewModel.currentStatus, .recording)
    }
    
    func testStatusViewModelUpdateWithProcessing() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: true,
            modelDownloadMessage: nil,
            progressMessage: "Converting audio...",
            hasPermission: true,
            showSuccess: false
        )
        
        XCTAssertEqual(viewModel.currentStatus, .processing("Converting audio..."))
    }
    
    func testStatusViewModelUpdateWithReady() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: false,
            modelDownloadMessage: nil,
            progressMessage: "",
            hasPermission: true,
            showSuccess: false
        )
        
        XCTAssertEqual(viewModel.currentStatus, .ready)
    }
    
    func testStatusViewModelUpdateWithPermissionRequired() {
        let viewModel = StatusViewModel()
        
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: false,
            modelDownloadMessage: nil,
            progressMessage: "",
            hasPermission: false,
            showSuccess: false
        )
        
        XCTAssertEqual(viewModel.currentStatus, .permissionRequired)
    }

    func testStatusViewModelUpdateWithModelDownloading() {
        let viewModel = StatusViewModel()

        viewModel.updateStatus(
            isRecording: false,
            isProcessing: false,
            modelDownloadMessage: "Downloading Base…",
            progressMessage: "",
            hasPermission: true,
            showSuccess: false
        )

        XCTAssertEqual(viewModel.currentStatus, .downloadingModel("Downloading Base…"))
    }
    
    func testStatusViewModelPriorityOrder() {
        let viewModel = StatusViewModel()
        
        // Error has highest priority
        viewModel.updateStatus(
            isRecording: true,
            isProcessing: true,
            modelDownloadMessage: nil,
            progressMessage: "Test",
            hasPermission: true,
            showSuccess: true,
            errorMessage: "Error"
        )
        XCTAssertEqual(viewModel.currentStatus, .error("Error"))
        
        // Success has second priority
        viewModel.updateStatus(
            isRecording: true,
            isProcessing: true,
            modelDownloadMessage: nil,
            progressMessage: "Test",
            hasPermission: true,
            showSuccess: true
        )
        XCTAssertEqual(viewModel.currentStatus, .success)
        
        // Recording has third priority
        viewModel.updateStatus(
            isRecording: true,
            isProcessing: true,
            modelDownloadMessage: nil,
            progressMessage: "Test",
            hasPermission: true,
            showSuccess: false
        )
        XCTAssertEqual(viewModel.currentStatus, .recording)
        
        // Processing has fourth priority
        viewModel.updateStatus(
            isRecording: false,
            isProcessing: true,
            modelDownloadMessage: nil,
            progressMessage: "Test",
            hasPermission: true,
            showSuccess: false
        )
        XCTAssertEqual(viewModel.currentStatus, .processing("Test"))
    }
    
    // MARK: - Performance Tests
    
    func testStatusUpdatePerformance() {
        let viewModel = StatusViewModel()
        
        measure {
            for i in 0..<1000 {
                viewModel.updateStatus(
                    isRecording: i % 2 == 0,
                    isProcessing: i % 3 == 0,
                    modelDownloadMessage: nil,
                    progressMessage: "Message \(i)",
                    hasPermission: true,
                    showSuccess: false
                )
            }
        }
    }
    
    func testAppStatusCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = AppStatus.processing("Processing \(i)")
                let _ = AppStatus.error("Error \(i)")
            }
        }
    }
}
