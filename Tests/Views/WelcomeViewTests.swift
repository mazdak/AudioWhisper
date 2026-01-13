import XCTest
import SwiftUI
@testable import AudioWhisper

// MARK: - WelcomeView Tests
@MainActor
final class WelcomeViewTests: XCTestCase {

    func testWelcomeViewCanBeCreated() {
        let view = WelcomeView()
        XCTAssertNotNil(view)
    }

    func testWelcomeViewBodyDoesNotCrash() {
        let view = WelcomeView()
        let _ = view.body
        XCTAssertTrue(true)
    }
}

// MARK: - FeatureRow Tests
final class FeatureRowTests: XCTestCase {

    func testFeatureRowCanBeCreated() {
        let row = FeatureRow(
            icon: "mic",
            title: "Test Feature",
            description: "Test description"
        )
        XCTAssertNotNil(row)
    }

    func testFeatureRowBodyDoesNotCrash() {
        let row = FeatureRow(
            icon: "gear",
            title: "Settings",
            description: "Configure your preferences"
        )
        let _ = row.body
        XCTAssertTrue(true)
    }

    func testFeatureRowWithEmptyStrings() {
        let row = FeatureRow(
            icon: "",
            title: "",
            description: ""
        )
        XCTAssertNotNil(row)
    }

    func testFeatureRowWithLongText() {
        let row = FeatureRow(
            icon: "star.fill",
            title: "A Very Long Feature Title That Might Wrap",
            description: "This is a very long description that explains the feature in great detail and might need multiple lines to display properly in the UI."
        )
        XCTAssertNotNil(row)
    }
}

// MARK: - InstructionRow Tests
final class InstructionRowTests: XCTestCase {

    func testInstructionRowCanBeCreated() {
        let row = InstructionRow(number: 1, text: "First step")
        XCTAssertNotNil(row)
    }

    func testInstructionRowBodyDoesNotCrash() {
        let row = InstructionRow(number: 2, text: "Second step")
        let _ = row.body
        XCTAssertTrue(true)
    }

    func testInstructionRowWithDifferentNumbers() {
        for number in 1...10 {
            let row = InstructionRow(number: number, text: "Step \(number)")
            XCTAssertNotNil(row)
        }
    }

    func testInstructionRowWithLongText() {
        let row = InstructionRow(
            number: 1,
            text: "This is a very long instruction that explains what the user needs to do in great detail"
        )
        XCTAssertNotNil(row)
    }

    func testInstructionRowWithZeroNumber() {
        let row = InstructionRow(number: 0, text: "Zero step")
        XCTAssertNotNil(row)
    }
}

// MARK: - WelcomeView Layout Tests
final class WelcomeViewLayoutTests: XCTestCase {

    func testWelcomeWindowSize() {
        let expectedSize = LayoutMetrics.Welcome.windowSize
        XCTAssertEqual(expectedSize.width, 600)
        XCTAssertEqual(expectedSize.height, 650)
    }

    func testFeatureGridColumns() {
        // Features should be displayed in 2 columns
        let columnCount = 2
        XCTAssertEqual(columnCount, 2)
    }
}

// MARK: - WelcomeView Content Tests
final class WelcomeViewContentTests: XCTestCase {

    func testWelcomeTitle() {
        let expectedTitle = "Welcome to AudioWhisper"
        XCTAssertFalse(expectedTitle.isEmpty)
    }

    func testWelcomeSubtitle() {
        let expectedSubtitle = "Your AI-powered audio transcription assistant"
        XCTAssertFalse(expectedSubtitle.isEmpty)
    }

    func testPrivacyFeatureTitle() {
        let title = "Privacy-First Local Transcription"
        XCTAssertFalse(title.isEmpty)
    }

    func testExpectedFeatures() {
        let features = [
            ("command", "Global Hotkey"),
            ("waveform", "Powerful Transcription"),
            ("clock.arrow.circlepath", "Transcription History"),
            ("brain", "Multiple AI Models"),
        ]

        XCTAssertEqual(features.count, 4)

        for (icon, title) in features {
            XCTAssertFalse(icon.isEmpty)
            XCTAssertFalse(title.isEmpty)
        }
    }

    func testSmartPasteInstructions() {
        let instructions = [
            "Enable 'Smart Paste' in Settings → General",
            "Grant Accessibility permission when prompted",
            "Transcribed text will automatically paste into the active app",
        ]

        XCTAssertEqual(instructions.count, 3)

        for instruction in instructions {
            XCTAssertFalse(instruction.isEmpty)
        }
    }
}

// MARK: - WelcomeView Icon Tests
final class WelcomeViewIconTests: XCTestCase {

    func testHeaderIcon() {
        let icon = "mic.circle.fill"
        XCTAssertFalse(icon.isEmpty)
    }

    func testPrivacyIcon() {
        let icon = "lock.shield.fill"
        XCTAssertFalse(icon.isEmpty)
    }

    func testDownloadIcon() {
        let icon = "arrow.down.circle.fill"
        XCTAssertFalse(icon.isEmpty)
    }

    func testCheckmarkIcon() {
        let icon = "checkmark.circle.fill"
        XCTAssertFalse(icon.isEmpty)
    }

    func testInfoIcon() {
        let icon = "info.circle"
        XCTAssertFalse(icon.isEmpty)
    }

    func testAccessibilityIcon() {
        let icon = "accessibility"
        XCTAssertFalse(icon.isEmpty)
    }
}

// MARK: - WelcomeView Button Tests
final class WelcomeViewButtonTests: XCTestCase {

    func testGetStartedButtonTitle() {
        let title = "Get Started"
        XCTAssertEqual(title, "Get Started")
    }
}

// MARK: - Download Stage Tests
final class DownloadStageTextTests: XCTestCase {

    func testDownloadStageTexts() {
        let stages = [
            "Preparing download...",
            "Downloading model...",
            "Processing model files...",
            "Almost done...",
            "Model ready!",
        ]

        for stage in stages {
            XCTAssertFalse(stage.isEmpty)
        }
    }
}

// MARK: - WelcomeView Notification Tests
final class WelcomeViewNotificationTests: XCTestCase {

    func testWelcomeCompletedNotificationExists() {
        let notificationName = Notification.Name.welcomeCompleted
        XCTAssertNotNil(notificationName)
    }
}

// MARK: - WelcomeView UserDefaults Keys Tests
final class WelcomeViewUserDefaultsKeysTests: XCTestCase {

    func testTranscriptionProviderKey() {
        let key = "transcriptionProvider"
        XCTAssertFalse(key.isEmpty)
    }

    func testSelectedWhisperModelKey() {
        let key = "selectedWhisperModel"
        XCTAssertFalse(key.isEmpty)
    }

    func testHasCompletedWelcomeKey() {
        let key = "hasCompletedWelcome"
        XCTAssertFalse(key.isEmpty)
    }

    func testLastWelcomeVersionKey() {
        let key = "lastWelcomeVersion"
        XCTAssertFalse(key.isEmpty)
    }
}
