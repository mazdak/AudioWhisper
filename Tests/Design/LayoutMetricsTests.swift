import XCTest
import CoreGraphics
@testable import AudioWhisper

// MARK: - LayoutMetrics RecordingWindow Tests
final class LayoutMetricsRecordingWindowTests: XCTestCase {

    func testRecordingWindowSize() {
        let size = LayoutMetrics.RecordingWindow.size
        XCTAssertEqual(size.width, 350)
        XCTAssertEqual(size.height, 160)
    }

    func testRecordingWindowCornerRadius() {
        let cornerRadius = LayoutMetrics.RecordingWindow.cornerRadius
        XCTAssertEqual(cornerRadius, 16)
    }

    func testRecordingWindowSizeIsReasonable() {
        let size = LayoutMetrics.RecordingWindow.size
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertLessThan(size.width, 1000)
        XCTAssertLessThan(size.height, 1000)
    }

    func testRecordingWindowCornerRadiusIsPositive() {
        let cornerRadius = LayoutMetrics.RecordingWindow.cornerRadius
        XCTAssertGreaterThan(cornerRadius, 0)
    }
}

// MARK: - LayoutMetrics DashboardWindow Tests
final class LayoutMetricsDashboardWindowTests: XCTestCase {

    func testDashboardWindowInitialSize() {
        let size = LayoutMetrics.DashboardWindow.initialSize
        XCTAssertEqual(size.width, 950)
        XCTAssertEqual(size.height, 700)
    }

    func testDashboardWindowMinimumSize() {
        let size = LayoutMetrics.DashboardWindow.minimumSize
        XCTAssertEqual(size.width, 800)
        XCTAssertEqual(size.height, 550)
    }

    func testDashboardWindowPreviewSize() {
        let size = LayoutMetrics.DashboardWindow.previewSize
        XCTAssertEqual(size.width, 900)
        XCTAssertEqual(size.height, 700)
    }

    func testDashboardWindowSidebarWidth() {
        let width = LayoutMetrics.DashboardWindow.sidebarWidth
        XCTAssertEqual(width, 200)
    }

    func testMinimumSizeIsSmallerThanInitial() {
        let initial = LayoutMetrics.DashboardWindow.initialSize
        let minimum = LayoutMetrics.DashboardWindow.minimumSize
        XCTAssertLessThanOrEqual(minimum.width, initial.width)
        XCTAssertLessThanOrEqual(minimum.height, initial.height)
    }

    func testSidebarWidthIsReasonable() {
        let sidebarWidth = LayoutMetrics.DashboardWindow.sidebarWidth
        let minimumWidth = LayoutMetrics.DashboardWindow.minimumSize.width
        XCTAssertLessThan(sidebarWidth, minimumWidth)
        XCTAssertGreaterThan(sidebarWidth, 100)
    }
}

// MARK: - LayoutMetrics TranscriptionHistory Tests
final class LayoutMetricsTranscriptionHistoryTests: XCTestCase {

    func testTranscriptionHistoryMinimumSize() {
        let size = LayoutMetrics.TranscriptionHistory.minimumSize
        XCTAssertEqual(size.width, 700)
        XCTAssertEqual(size.height, 400)
    }

    func testTranscriptionHistoryPreviewSize() {
        let size = LayoutMetrics.TranscriptionHistory.previewSize
        XCTAssertEqual(size.width, 700)
        XCTAssertEqual(size.height, 500)
    }

    func testPreviewSizeIsAtLeastMinimum() {
        let minimum = LayoutMetrics.TranscriptionHistory.minimumSize
        let preview = LayoutMetrics.TranscriptionHistory.previewSize
        XCTAssertGreaterThanOrEqual(preview.width, minimum.width)
        XCTAssertGreaterThanOrEqual(preview.height, minimum.height)
    }
}

// MARK: - LayoutMetrics Welcome Tests
final class LayoutMetricsWelcomeTests: XCTestCase {

    func testWelcomeWindowSize() {
        let size = LayoutMetrics.Welcome.windowSize
        XCTAssertEqual(size.width, 600)
        XCTAssertEqual(size.height, 650)
    }

    func testWelcomeWindowSizeIsReasonable() {
        let size = LayoutMetrics.Welcome.windowSize
        XCTAssertGreaterThan(size.width, 400)
        XCTAssertGreaterThan(size.height, 400)
        XCTAssertLessThan(size.width, 1200)
        XCTAssertLessThan(size.height, 1200)
    }
}

// MARK: - LayoutMetrics Consistency Tests
final class LayoutMetricsConsistencyTests: XCTestCase {

    func testAllSizesHavePositiveDimensions() {
        let sizes: [CGSize] = [
            LayoutMetrics.RecordingWindow.size,
            LayoutMetrics.DashboardWindow.initialSize,
            LayoutMetrics.DashboardWindow.minimumSize,
            LayoutMetrics.DashboardWindow.previewSize,
            LayoutMetrics.TranscriptionHistory.minimumSize,
            LayoutMetrics.TranscriptionHistory.previewSize,
            LayoutMetrics.Welcome.windowSize,
        ]

        for size in sizes {
            XCTAssertGreaterThan(size.width, 0)
            XCTAssertGreaterThan(size.height, 0)
        }
    }

    func testAllWidthsAreReasonable() {
        let widths: [CGFloat] = [
            LayoutMetrics.RecordingWindow.size.width,
            LayoutMetrics.DashboardWindow.initialSize.width,
            LayoutMetrics.DashboardWindow.minimumSize.width,
            LayoutMetrics.DashboardWindow.sidebarWidth,
            LayoutMetrics.TranscriptionHistory.minimumSize.width,
            LayoutMetrics.Welcome.windowSize.width,
        ]

        for width in widths {
            XCTAssertGreaterThan(width, 100)
            XCTAssertLessThan(width, 2000)
        }
    }

    func testAllHeightsAreReasonable() {
        let heights: [CGFloat] = [
            LayoutMetrics.RecordingWindow.size.height,
            LayoutMetrics.DashboardWindow.initialSize.height,
            LayoutMetrics.DashboardWindow.minimumSize.height,
            LayoutMetrics.TranscriptionHistory.minimumSize.height,
            LayoutMetrics.Welcome.windowSize.height,
        ]

        for height in heights {
            XCTAssertGreaterThan(height, 100)
            XCTAssertLessThan(height, 2000)
        }
    }
}

// MARK: - LayoutMetrics Aspect Ratio Tests
final class LayoutMetricsAspectRatioTests: XCTestCase {

    func testRecordingWindowAspectRatio() {
        let size = LayoutMetrics.RecordingWindow.size
        let aspectRatio = size.width / size.height
        // Should be wider than tall
        XCTAssertGreaterThan(aspectRatio, 1.0)
    }

    func testDashboardWindowAspectRatio() {
        let size = LayoutMetrics.DashboardWindow.initialSize
        let aspectRatio = size.width / size.height
        // Should be wider than tall
        XCTAssertGreaterThan(aspectRatio, 1.0)
    }

    func testTranscriptionHistoryAspectRatio() {
        let size = LayoutMetrics.TranscriptionHistory.minimumSize
        let aspectRatio = size.width / size.height
        // Should be wider than tall
        XCTAssertGreaterThan(aspectRatio, 1.0)
    }

    func testWelcomeWindowAspectRatio() {
        let size = LayoutMetrics.Welcome.windowSize
        let aspectRatio = size.width / size.height
        // Welcome window is roughly square, slightly taller than wide
        XCTAssertLessThanOrEqual(aspectRatio, 1.0)
    }
}
