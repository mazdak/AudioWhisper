import XCTest
import Foundation
@testable import AudioWhisper

class TranscriptionTypesTests: XCTestCase {
    
    // MARK: - TranscriptionProvider Tests
    
    func testTranscriptionProviderCases() {
        let allCases = TranscriptionProvider.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.openai))
        XCTAssertTrue(allCases.contains(.gemini))
        XCTAssertTrue(allCases.contains(.local))
    }
    
    func testTranscriptionProviderDisplayNames() {
        XCTAssertEqual(TranscriptionProvider.openai.displayName, "OpenAI Whisper (Cloud)")
        XCTAssertEqual(TranscriptionProvider.gemini.displayName, "Google Gemini (Cloud)")
        XCTAssertEqual(TranscriptionProvider.local.displayName, "Local Whisper")
    }
    
    func testTranscriptionProviderRawValues() {
        XCTAssertEqual(TranscriptionProvider.openai.rawValue, "openai")
        XCTAssertEqual(TranscriptionProvider.gemini.rawValue, "gemini")
        XCTAssertEqual(TranscriptionProvider.local.rawValue, "local")
    }
    
    func testTranscriptionProviderFromRawValue() {
        XCTAssertEqual(TranscriptionProvider(rawValue: "openai"), .openai)
        XCTAssertEqual(TranscriptionProvider(rawValue: "gemini"), .gemini)
        XCTAssertEqual(TranscriptionProvider(rawValue: "local"), .local)
        XCTAssertNil(TranscriptionProvider(rawValue: "invalid"))
    }
    
    func testTranscriptionProviderCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding
        let openaiData = try encoder.encode(TranscriptionProvider.openai)
        let geminiData = try encoder.encode(TranscriptionProvider.gemini)
        let localData = try encoder.encode(TranscriptionProvider.local)
        
        // Test decoding
        let decodedOpenai = try decoder.decode(TranscriptionProvider.self, from: openaiData)
        let decodedGemini = try decoder.decode(TranscriptionProvider.self, from: geminiData)
        let decodedLocal = try decoder.decode(TranscriptionProvider.self, from: localData)
        
        XCTAssertEqual(decodedOpenai, .openai)
        XCTAssertEqual(decodedGemini, .gemini)
        XCTAssertEqual(decodedLocal, .local)
    }
    
    // MARK: - WhisperModel Tests
    
    func testWhisperModelCases() {
        let allCases = WhisperModel.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.tiny))
        XCTAssertTrue(allCases.contains(.base))
        XCTAssertTrue(allCases.contains(.small))
        XCTAssertTrue(allCases.contains(.largeTurbo))
    }
    
    func testWhisperModelDisplayNames() {
        XCTAssertEqual(WhisperModel.tiny.displayName, "Tiny (39MB)")
        XCTAssertEqual(WhisperModel.base.displayName, "Base (142MB)")
        XCTAssertEqual(WhisperModel.small.displayName, "Small (466MB)")
        XCTAssertEqual(WhisperModel.largeTurbo.displayName, "Large Turbo (1.5GB)")
    }
    
    func testWhisperModelFileSizes() {
        XCTAssertEqual(WhisperModel.tiny.fileSize, "39MB")
        XCTAssertEqual(WhisperModel.base.fileSize, "142MB")
        XCTAssertEqual(WhisperModel.small.fileSize, "466MB")
        XCTAssertEqual(WhisperModel.largeTurbo.fileSize, "1.5GB")
    }
    
    func testWhisperModelFileNames() {
        XCTAssertEqual(WhisperModel.tiny.fileName, "ggml-tiny.bin")
        XCTAssertEqual(WhisperModel.base.fileName, "ggml-base.bin")
        XCTAssertEqual(WhisperModel.small.fileName, "ggml-small.bin")
        XCTAssertEqual(WhisperModel.largeTurbo.fileName, "ggml-large-v3-turbo.bin")
    }
    
    func testWhisperModelDownloadURLs() {
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        
        XCTAssertEqual(WhisperModel.tiny.downloadURL.absoluteString, "\(baseURL)/ggml-tiny.bin")
        XCTAssertEqual(WhisperModel.base.downloadURL.absoluteString, "\(baseURL)/ggml-base.bin")
        XCTAssertEqual(WhisperModel.small.downloadURL.absoluteString, "\(baseURL)/ggml-small.bin")
        XCTAssertEqual(WhisperModel.largeTurbo.downloadURL.absoluteString, "\(baseURL)/ggml-large-v3-turbo.bin")
    }
    
    func testWhisperModelDescriptions() {
        XCTAssertEqual(WhisperModel.tiny.description, "Fastest, basic accuracy")
        XCTAssertEqual(WhisperModel.base.description, "Good balance of speed and accuracy")
        XCTAssertEqual(WhisperModel.small.description, "Better accuracy, reasonable speed")
        XCTAssertEqual(WhisperModel.largeTurbo.description, "Highest accuracy, optimized for speed")
    }
    
    func testWhisperModelRawValues() {
        XCTAssertEqual(WhisperModel.tiny.rawValue, "tiny")
        XCTAssertEqual(WhisperModel.base.rawValue, "base")
        XCTAssertEqual(WhisperModel.small.rawValue, "small")
        XCTAssertEqual(WhisperModel.largeTurbo.rawValue, "large-v3-turbo")
    }
    
    func testWhisperModelFromRawValue() {
        XCTAssertEqual(WhisperModel(rawValue: "tiny"), .tiny)
        XCTAssertEqual(WhisperModel(rawValue: "base"), .base)
        XCTAssertEqual(WhisperModel(rawValue: "small"), .small)
        XCTAssertEqual(WhisperModel(rawValue: "large-v3-turbo"), .largeTurbo)
        XCTAssertNil(WhisperModel(rawValue: "invalid"))
    }
    
    func testWhisperModelCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding all models
        for model in WhisperModel.allCases {
            let data = try encoder.encode(model)
            let decoded = try decoder.decode(WhisperModel.self, from: data)
            XCTAssertEqual(decoded, model)
        }
    }
    
    // MARK: - URL Validation Tests
    
    func testDownloadURLsAreValid() {
        for model in WhisperModel.allCases {
            let url = model.downloadURL
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "huggingface.co")
            XCTAssertTrue(url.path.contains("whisper.cpp"))
            XCTAssertTrue(url.path.hasSuffix(".bin"))
        }
    }
    
    func testDownloadURLsAreUnique() {
        let urls = WhisperModel.allCases.map { $0.downloadURL.absoluteString }
        let uniqueUrls = Set(urls)
        XCTAssertEqual(urls.count, uniqueUrls.count, "All download URLs should be unique")
    }
    
    // MARK: - File Size Validation Tests
    
    func testFileSizesAreNotEmpty() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.fileSize.isEmpty, "File size for \(model) should not be empty")
        }
    }
    
    func testFileSizesContainUnits() {
        // File sizes should contain size units (MB or GB)
        for model in WhisperModel.allCases {
            let size = model.fileSize
            XCTAssertTrue(size.contains("MB") || size.contains("GB"), "File size for \(model) should contain MB or GB")
        }
    }
    
    func testFileSizesFollowExpectedPattern() {
        // Test specific file sizes match expected values
        XCTAssertTrue(WhisperModel.tiny.fileSize.contains("39"))
        XCTAssertTrue(WhisperModel.base.fileSize.contains("142"))
        XCTAssertTrue(WhisperModel.small.fileSize.contains("466"))
        XCTAssertTrue(WhisperModel.largeTurbo.fileSize.contains("1.5"))
    }
    
    // MARK: - File Name Validation Tests
    
    func testFileNamesAreValid() {
        for model in WhisperModel.allCases {
            let fileName = model.fileName
            XCTAssertTrue(fileName.hasPrefix("ggml-"))
            XCTAssertTrue(fileName.hasSuffix(".bin"))
            XCTAssertFalse(fileName.contains(" "))
            XCTAssertFalse(fileName.contains(".."))
        }
    }
    
    func testFileNamesAreUnique() {
        let fileNames = WhisperModel.allCases.map { $0.fileName }
        let uniqueFileNames = Set(fileNames)
        XCTAssertEqual(fileNames.count, uniqueFileNames.count, "All file names should be unique")
    }
    
    // MARK: - Display Name Validation Tests
    
    func testDisplayNamesAreNotEmpty() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.displayName.isEmpty, "Display name for \(model) should not be empty")
        }
    }
    
    func testDisplayNamesContainSizeInfo() {
        for model in WhisperModel.allCases {
            let displayName = model.displayName
            XCTAssertTrue(displayName.contains("MB") || displayName.contains("GB"), 
                         "Display name for \(model) should contain size information")
        }
    }
    
    func testDisplayNamesAreUnique() {
        let displayNames = WhisperModel.allCases.map { $0.displayName }
        let uniqueDisplayNames = Set(displayNames)
        XCTAssertEqual(displayNames.count, uniqueDisplayNames.count, "All display names should be unique")
    }
    
    // MARK: - Description Validation Tests
    
    func testDescriptionsAreNotEmpty() {
        for model in WhisperModel.allCases {
            XCTAssertFalse(model.description.isEmpty, "Description for \(model) should not be empty")
        }
    }
    
    func testDescriptionsContainUsefulInfo() {
        // Each description should contain information about speed or accuracy
        for model in WhisperModel.allCases {
            let description = model.description.lowercased()
            let hasSpeedInfo = description.contains("fast") || description.contains("slow") || description.contains("speed")
            let hasAccuracyInfo = description.contains("accuracy") || description.contains("accurate")
            XCTAssertTrue(hasSpeedInfo || hasAccuracyInfo, 
                         "Description for \(model) should contain speed or accuracy information")
        }
    }
    
    // MARK: - Model Comparison Tests
    
    func testModelOrderingBySize() {
        // Test that models are in expected order based on size strings
        // Test that tiny, base, and small are MB, largeTurbo is GB
        XCTAssertTrue(WhisperModel.tiny.fileSize.contains("MB"))
        XCTAssertTrue(WhisperModel.base.fileSize.contains("MB"))
        XCTAssertTrue(WhisperModel.small.fileSize.contains("MB"))
        XCTAssertTrue(WhisperModel.largeTurbo.fileSize.contains("GB"))
    }
    
    // MARK: - Performance Tests
    
    func testModelPropertiesPerformance() {
        measure {
            for model in WhisperModel.allCases {
                _ = model.displayName
                _ = model.fileSize
                _ = model.fileName
                _ = model.downloadURL
                _ = model.description
            }
        }
    }
    
    func testProviderPropertiesPerformance() {
        measure {
            for provider in TranscriptionProvider.allCases {
                _ = provider.displayName
                _ = provider.rawValue
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testModelInitializationWithAllCases() {
        // Ensure all cases can be initialized
        for model in WhisperModel.allCases {
            XCTAssertNotNil(model)
            XCTAssertNotNil(WhisperModel(rawValue: model.rawValue))
        }
    }
    
    func testProviderInitializationWithAllCases() {
        // Ensure all cases can be initialized
        for provider in TranscriptionProvider.allCases {
            XCTAssertNotNil(provider)
            XCTAssertNotNil(TranscriptionProvider(rawValue: provider.rawValue))
        }
    }
    
    // MARK: - String Representation Tests
    
    func testModelStringRepresentation() {
        for model in WhisperModel.allCases {
            let string = String(describing: model)
            XCTAssertFalse(string.isEmpty)
            // String representation contains the case name, not necessarily the raw value
            XCTAssertTrue(string.count > 0)
        }
    }
    
    func testProviderStringRepresentation() {
        for provider in TranscriptionProvider.allCases {
            let string = String(describing: provider)
            XCTAssertFalse(string.isEmpty)
            // String representation contains the case name, not necessarily the raw value
            XCTAssertTrue(string.count > 0)
        }
    }
}