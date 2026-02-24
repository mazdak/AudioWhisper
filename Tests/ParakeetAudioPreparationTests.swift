import XCTest
import AVFoundation
@testable import AudioWhisper

final class ParakeetAudioPreparationTests: XCTestCase {
    private final class LockedStringBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: String?

        func set(_ newValue: String?) {
            lock.lock()
            value = newValue
            lock.unlock()
        }

        func get() -> String? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        await MLDaemonManager.shared.resetForTesting()
    }

    override func tearDown() async throws {
        await MLDaemonManager.shared.resetForTesting()
        try await super.tearDown()
    }

    func testProcessAudioToRawPCMProducesNonEmptyRawFile() async throws {
        let service = ParakeetService()
        let inputURL = try makeTempAudioFile(sampleRate: 44_100, frameCount: 4_410)
        defer { try? FileManager.default.removeItem(at: inputURL) }

        let rawURL = try await service.processAudioToRawPCMForTesting(audioFileURL: inputURL)
        defer { try? FileManager.default.removeItem(at: rawURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: rawURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: rawURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        XCTAssertGreaterThan(size, 0)
    }

    func testProcessAudioToRawPCMThrowsTranscriptionFailedForMissingFile() async {
        let service = ParakeetService()
        let missingURL = URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).m4a")

        do {
            _ = try await service.processAudioToRawPCMForTesting(audioFileURL: missingURL)
            XCTFail("Expected transcriptionFailed error")
        } catch let error as ParakeetError {
            guard case .transcriptionFailed(let message) = error else {
                return XCTFail("Expected transcriptionFailed, got \(error)")
            }
            XCTAssertTrue(message.contains("Failed to open audio file"))
        } catch {
            XCTFail("Expected ParakeetError, got \(error)")
        }
    }

    func testTranscribeAndCleanupForTestingRemovesTemporaryPCMFile() async throws {
        let service = ParakeetService()
        let inputURL = try makeTempAudioFile(sampleRate: 44_100, frameCount: 4_410)
        defer { try? FileManager.default.removeItem(at: inputURL) }

        let capturedPCMPath = LockedStringBox()
        await MLDaemonManager.shared.setTestResponder { method, params in
            if method == "transcribe" {
                capturedPCMPath.set(params["pcm_path"] as? String)
                return ["success": true, "text": "ok", "error": NSNull()]
            }
            return ["success": true]
        }

        let result = try await service.transcribeAndCleanupForTesting(audioFileURL: inputURL)
        XCTAssertEqual(result.text, "ok")

        guard let pcmPath = capturedPCMPath.get() else {
            return XCTFail("Expected captured pcm_path from daemon request")
        }
        XCTAssertEqual(result.pcmPath, pcmPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pcmPath), "Temporary PCM file should be removed after transcription")
    }

    private func makeTempAudioFile(sampleRate: Double, frameCount: Int) throws -> URL {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0]
        else {
            XCTFail("Failed to create test audio format")
            throw NSError(domain: "ParakeetAudioPreparationTests", code: 1)
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        for index in 0..<frameCount {
            let phase = Float(index) / Float(sampleRate) * 2.0 * .pi * 220.0
            channel[index] = sin(phase)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet-prep-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
