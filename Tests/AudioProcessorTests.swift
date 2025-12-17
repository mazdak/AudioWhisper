import XCTest
import AVFoundation
import AudioToolbox
@testable import AudioWhisper

final class AudioProcessorTests: XCTestCase {
    func testLoadAudioReadsSamplesVerbatimAtSameRate() throws {
        let originalSamples: [Float] = [0, 0.25, -0.25, 0.75, -0.75]
        let url = try makeTempAudioFile(samples: originalSamples, sampleRate: 48_000)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try loadAudio(url: url, samplingRate: 48_000)

        XCTAssertEqual(loaded.count, originalSamples.count)
        zip(loaded, originalSamples).forEach { loadedSample, expected in
            XCTAssertEqual(loadedSample, expected, accuracy: 0.0001)
        }
    }

    func testLoadAudioResamplesToRequestedRate() throws {
        let duration: Double = 0.05 // seconds
        let sourceRate: Double = 24_000
        let targetRate = 48_000
        let frameCount = Int(sourceRate * duration)
        let sineWave = (0..<frameCount).map { index -> Float in
            let theta = Double(index) / sourceRate * 2 * Double.pi * 440
            return Float(sin(theta))
        }

        let url = try makeTempAudioFile(samples: sineWave, sampleRate: sourceRate)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try loadAudio(url: url, samplingRate: targetRate)

        let expectedFrames = Int(duration * Double(targetRate))
        XCTAssertLessThanOrEqual(abs(loaded.count - expectedFrames), 4, "Resampled frame count should match target rate within tolerance")
        XCTAssertNotEqual(loaded.prefix(10).reduce(0, +), 0, "Resampled data should retain non-zero content")
    }

    func testLoadAudioThrowsOpenFailedForMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).wav")

        XCTAssertThrowsError(try loadAudio(url: url, samplingRate: 44_100)) { error in
            guard case let AudioLoadError.openFailed(status) = error else {
                return XCTFail("Expected openFailed error")
            }
            XCTAssertNotEqual(status, noErr)
        }
    }

    // MARK: - Helpers

    private func makeTempAudioFile(samples: [Float], sampleRate: Double) throws -> URL {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (index, sample) in samples.enumerated() {
                channel[index] = sample
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
