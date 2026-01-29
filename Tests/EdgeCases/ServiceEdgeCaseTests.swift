import XCTest
@testable import AudioWhisper

// MARK: - TranscriptionProvider Edge Cases
final class TranscriptionProviderEdgeCaseTests: XCTestCase {

    func testAllProvidersHaveDisplayNames() {
        for provider in TranscriptionProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
        }
    }

    func testAllProvidersHaveRawValues() {
        for provider in TranscriptionProvider.allCases {
            XCTAssertFalse(provider.rawValue.isEmpty)
        }
    }

    func testProviderFromInvalidRawValue() {
        let provider = TranscriptionProvider(rawValue: "invalid_provider")
        XCTAssertNil(provider)
    }

    func testProviderFromEmptyRawValue() {
        let provider = TranscriptionProvider(rawValue: "")
        XCTAssertNil(provider)
    }

    func testProviderRoundtrip() {
        for provider in TranscriptionProvider.allCases {
            let rawValue = provider.rawValue
            let reconstructed = TranscriptionProvider(rawValue: rawValue)
            XCTAssertEqual(provider, reconstructed)
        }
    }
}

// MARK: - WhisperModel Edge Cases
final class WhisperModelEdgeCaseTests: XCTestCase {

    func testAllModelsHaveDisplayNames() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty)
        }
    }

    func testAllModelsHaveFileSizes() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.fileSize.isEmpty)
        }
    }

    func testAllModelsHaveEstimatedSizes() {
        for model in WhisperModel.allCases {
            XCTAssertGreaterThan(model.estimatedSize, 0)
        }
    }

    func testAllModelsHaveWhisperKitNames() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.whisperKitModelName.isEmpty)
            XCTAssertTrue(model.whisperKitModelName.hasPrefix("openai_whisper-"))
        }
    }

    func testModelFromInvalidRawValue() {
        let model = WhisperModel(rawValue: "invalid_model")
        XCTAssertNil(model)
    }

    func testModelFromEmptyRawValue() {
        let model = WhisperModel(rawValue: "")
        XCTAssertNil(model)
    }

    func testModelRoundtrip() {
        for model in WhisperModel.allCases {
            let rawValue = model.rawValue
            let reconstructed = WhisperModel(rawValue: rawValue)
            XCTAssertEqual(model, reconstructed)
        }
    }
}

// MARK: - TranscriptionRecord Edge Cases
@MainActor
final class TranscriptionRecordEdgeCaseTests: XCTestCase {

    func testRecordWithEmptyText() {
        let record = TranscriptionRecord(
            text: "",
            provider: .openai,
            duration: 5.0
        )
        XCTAssertNotNil(record)
        XCTAssertTrue(record.text.isEmpty)
    }

    func testRecordWithVeryLongText() {
        let longText = String(repeating: "Test ", count: 10000)
        let record = TranscriptionRecord(
            text: longText,
            provider: .openai,
            duration: 300.0
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record.text.count, longText.count)
    }

    func testRecordWithZeroDuration() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .openai,
            duration: 0.0
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record.duration, 0.0)
    }

    func testRecordWithNegativeDuration() {
        let record = TranscriptionRecord(
            text: "Test",
            provider: .openai,
            duration: -5.0
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record.duration, -5.0)
    }

    func testProviderRawValueLookupWithUnknown() {
        // Test that invalid raw values return nil when looking up provider
        let invalidProvider = TranscriptionProvider(rawValue: "unknown_provider")
        XCTAssertNil(invalidProvider)
    }

    func testProviderRawValueLookupWithEmpty() {
        // Test that empty raw value returns nil when looking up provider
        let emptyProvider = TranscriptionProvider(rawValue: "")
        XCTAssertNil(emptyProvider)
    }

    func testRecordWithSpecialCharactersInText() {
        let specialText = "Test with émojis 🎤 and special chars: <>&\"'"
        let record = TranscriptionRecord(
            text: specialText,
            provider: .openai,
            duration: 5.0
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record.text, specialText)
    }

    func testRecordWithUnicodeText() {
        let unicodeText = "日本語テスト 中文测试 العربية"
        let record = TranscriptionRecord(
            text: unicodeText,
            provider: .gemini,
            duration: 10.0
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record.text, unicodeText)
    }
}

// MARK: - AppStatus Edge Cases
final class AppStatusEdgeCaseTests: XCTestCase {

    func testReadyStatus() {
        let status = AppStatus.ready
        XCTAssertFalse(status.shouldAnimate)
    }

    func testRecordingStatus() {
        let status = AppStatus.recording
        XCTAssertTrue(status.shouldAnimate)
    }

    func testProcessingWithEmptyMessage() {
        let status = AppStatus.processing("")
        if case .processing(let message) = status {
            XCTAssertTrue(message.isEmpty)
        } else {
            XCTFail("Expected processing status")
        }
    }

    func testProcessingWithLongMessage() {
        let longMessage = String(repeating: "Processing ", count: 100)
        let status = AppStatus.processing(longMessage)
        if case .processing(let message) = status {
            XCTAssertEqual(message, longMessage)
        } else {
            XCTFail("Expected processing status")
        }
    }

    func testErrorWithEmptyMessage() {
        let status = AppStatus.error("")
        if case .error(let message) = status {
            XCTAssertTrue(message.isEmpty)
        } else {
            XCTFail("Expected error status")
        }
    }

    func testErrorWithSpecialCharacters() {
        let errorMessage = "Error: <script>alert('xss')</script>"
        let status = AppStatus.error(errorMessage)
        if case .error(let message) = status {
            XCTAssertEqual(message, errorMessage)
        } else {
            XCTFail("Expected error status")
        }
    }
}

// MARK: - UvError Edge Cases
final class UvErrorEdgeCaseTests: XCTestCase {

    func testUvTooOldWithEmptyVersions() {
        let error = UvError.uvTooOld(found: "", required: "")
        XCTAssertNotNil(error.errorDescription)
    }

    func testUvTooOldWithSameVersion() {
        let error = UvError.uvTooOld(found: "0.8.5", required: "0.8.5")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("0.8.5") ?? false)
    }

    func testPythonNotUsableWithEmptyMessage() {
        let error = UvError.pythonNotUsable("")
        XCTAssertNotNil(error.errorDescription)
    }

    func testVenvCreationFailedWithSpecialChars() {
        let error = UvError.venvCreationFailed("Permission denied: /path/with spaces/file")
        XCTAssertNotNil(error.errorDescription)
    }

    func testSyncFailedWithLongMessage() {
        let longMessage = String(repeating: "Error ", count: 100)
        let error = UvError.syncFailed(longMessage)
        XCTAssertNotNil(error.errorDescription)
    }
}

// MARK: - Color Hex Edge Cases
final class ColorHexEdgeCaseTests: XCTestCase {

    func testHexWithOnlyHash() {
        let color = Color(hex: "#")
        XCTAssertNil(color)
    }

    func testHexWithFourDigits() {
        let color = Color(hex: "#FFFF")
        XCTAssertNil(color)
    }

    func testHexWithFiveDigits() {
        let color = Color(hex: "#FFFFF")
        XCTAssertNil(color)
    }

    func testHexWithSevenDigits() {
        let color = Color(hex: "#FFFFFFF")
        XCTAssertNil(color)
    }

    func testHexWithNonHexCharacters() {
        let color = Color(hex: "#GHIJKL")
        XCTAssertNil(color)
    }

    func testHexWithMixedValidInvalid() {
        let color = Color(hex: "#FF00GG")
        XCTAssertNil(color)
    }

    func testHexWithSpacesInMiddle() {
        let color = Color(hex: "#FF 00 FF")
        XCTAssertNil(color)
    }
}

// MARK: - Waveform Calculation Edge Cases
final class WaveformCalculationEdgeCaseTests: XCTestCase {

    func testIdleBreathWithNegativePhase() {
        let value = CircularSpectrumView.testableIdleBreathValue(phase: -1.0, barIndex: 0)
        XCTAssertGreaterThanOrEqual(value, 0)
    }

    func testIdleBreathWithVeryLargePhase() {
        let value = CircularSpectrumView.testableIdleBreathValue(phase: 1000000.0, barIndex: 0)
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 1.0)
    }

    func testIdleBreathWithNegativeBarIndex() {
        let value = CircularSpectrumView.testableIdleBreathValue(phase: 0, barIndex: -1)
        XCTAssertGreaterThanOrEqual(value, 0)
    }

    func testSmoothedLevelWithEqualValues() {
        let result = CircularSpectrumView.testableSmoothedLevel(current: 0.5, target: 0.5)
        XCTAssertEqual(result, 0.5, accuracy: 0.001)
    }

    func testSmoothedLevelWithZeroValues() {
        let result = CircularSpectrumView.testableSmoothedLevel(current: 0, target: 0)
        XCTAssertEqual(result, 0)
    }

    func testSmoothedLevelWithMaxValues() {
        let result = CircularSpectrumView.testableSmoothedLevel(current: 1.0, target: 1.0)
        XCTAssertEqual(result, 1.0)
    }

    func testGainBoostWithZero() {
        let result = SpectrumWaveformView.testableApplyGainBoost(0)
        XCTAssertEqual(result, 0)
    }

    func testGainBoostWithOne() {
        let result = SpectrumWaveformView.testableApplyGainBoost(1.0)
        XCTAssertEqual(result, 1.0) // Clamped to 1.0
    }

    func testGainBoostWithNegative() {
        let result = SpectrumWaveformView.testableApplyGainBoost(-0.5)
        XCTAssertLessThan(result, 0) // Negative values aren't clamped
    }
}

import SwiftUI
