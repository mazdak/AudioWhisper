import XCTest
import AVFoundation
@testable import AudioWhisper

final class AudioValidatorTests: XCTestCase {
    
    func testValidateAudioFileReturnsFileNotFound() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).wav")
        
        let result = await AudioValidator.validateAudioFile(at: missingURL)
        
        guard case .invalid(.fileNotFound) = result else {
            return XCTFail("Expected fileNotFound, got \(result)")
        }
    }
    
    func testValidateAudioFileRejectsEmptyFile() async throws {
        let url = try temporaryFile(extension: "wav", contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }
        
        let result = await AudioValidator.validateAudioFile(at: url)
        
        guard case .invalid(.emptyFile) = result else {
            return XCTFail("Expected emptyFile, got \(result)")
        }
    }
    
    func testValidateAudioFileRejectsUnsupportedFormat() async throws {
        let url = try temporaryFile(extension: "txt", contents: Data([0x00, 0x01]))
        defer { try? FileManager.default.removeItem(at: url) }
        
        let result = await AudioValidator.validateAudioFile(at: url)
        
        guard case .invalid(.unsupportedFormat("txt")) = result else {
            return XCTFail("Expected unsupportedFormat(txt), got \(result)")
        }
    }
    
    func testValidateAudioFileReturnsValidForWellFormedAudio() async throws {
        let url = try makeValidAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        
        let result = await AudioValidator.validateAudioFile(at: url)
        
        guard case .valid(let info) = result else {
            return XCTFail("Expected valid result, got \(result)")
        }
        
        XCTAssertTrue(result.isValid)
        XCTAssertGreaterThan(info.sampleRate, 0)
        XCTAssertGreaterThan(info.channelCount, 0)
        XCTAssertGreaterThan(info.duration, 0)
        XCTAssertGreaterThan(info.fileSize, 0)
    }
    
    func testValidateAudioFileDetectsCorruptedAudio() async throws {
        let url = try makeCorruptedAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        
        let result = await AudioValidator.validateAudioFile(at: url)
        
        guard case .invalid(.corruptedFile) = result else {
            return XCTFail("Expected corruptedFile, got \(result)")
        }
    }
    
    func testIsFormatSupportedMatchesKnownExtensions() {
        let supported = URL(fileURLWithPath: "/tmp/audio.mp3")
        let unsupported = URL(fileURLWithPath: "/tmp/audio.doc")
        
        XCTAssertTrue(AudioValidator.isFormatSupported(url: supported))
        XCTAssertFalse(AudioValidator.isFormatSupported(url: unsupported))
    }
    
    func testIsFileSizeValidEnforcesLimit() throws {
        let smallFile = try temporaryFile(extension: "wav", contents: Data(repeating: 0xAA, count: 1_024))
        let largeFile = try temporaryFile(extension: "wav", contents: Data(repeating: 0xBB, count: 2_000_000))
        defer {
            try? FileManager.default.removeItem(at: smallFile)
            try? FileManager.default.removeItem(at: largeFile)
        }
        
        XCTAssertTrue(AudioValidator.isFileSizeValid(url: smallFile, maxSizeInMB: 1))
        XCTAssertFalse(AudioValidator.isFileSizeValid(url: largeFile, maxSizeInMB: 1))
    }
    
    // MARK: - Helpers
    
    private func temporaryFile(extension fileExtension: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioValidatorTests-\(UUID().uuidString).\(fileExtension)")
        FileManager.default.createFile(atPath: url.path, contents: contents, attributes: nil)
        return url
    }
    
    private func makeValidAudioFile() throws -> URL {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            throw NSError(domain: "AudioValidatorTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create audio format"])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudioValidatorTests-valid-\(UUID().uuidString).wav")
        
        let frameCount: AVAudioFrameCount = 1_024
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioValidatorTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create buffer"])
        }
        buffer.frameLength = frameCount
        
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
    
    private func makeCorruptedAudioFile() throws -> URL {
        let payload = Data("not a real wav file".utf8)
        return try temporaryFile(extension: "wav", contents: payload)
    }
}
