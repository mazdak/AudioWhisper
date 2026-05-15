import XCTest
@testable import AudioWhisper

final class DiskMutationSerializerTests: XCTestCase {

    // MARK: - Serializer

    func test_serializer_runsSequentialCallsOnSameKey() async throws {
        let serializer = DiskMutationSerializer<String>()
        let counter = Counter()

        try await serializer.run(key: "alpha") {
            await counter.increment()
        }
        try await serializer.run(key: "alpha") {
            await counter.increment()
        }
        try await serializer.run(key: "alpha") {
            await counter.increment()
        }

        let final = await counter.value
        XCTAssertEqual(final, 3)
    }

    func test_serializer_concurrentSameKeyCallersShareTask() async throws {
        // Two concurrent callers for the same key should share one in-flight
        // task: the body runs exactly once.
        let serializer = DiskMutationSerializer<String>()
        let counter = Counter()

        async let a: Void = try serializer.run(key: "shared") {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            await counter.increment()
        }
        async let b: Void = try serializer.run(key: "shared") {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            await counter.increment()
        }

        _ = try await (a, b)
        let final = await counter.value
        XCTAssertEqual(final, 1, "Concurrent same-key callers should run the body exactly once")
    }

    func test_serializer_differentKeysRunInParallel() async throws {
        // Different keys should not block each other.
        let serializer = DiskMutationSerializer<String>()
        let counter = Counter()

        async let a: Void = try serializer.run(key: "one") {
            try await Task.sleep(nanoseconds: 50_000_000)
            await counter.increment()
        }
        async let b: Void = try serializer.run(key: "two") {
            try await Task.sleep(nanoseconds: 50_000_000)
            await counter.increment()
        }

        let start = Date()
        _ = try await (a, b)
        let elapsed = Date().timeIntervalSince(start)
        let final = await counter.value
        XCTAssertEqual(final, 2)
        XCTAssertLessThan(elapsed, 0.15, "Different-keyed callers should run in parallel, not be serialized")
    }

    func test_serializer_propagatesErrors() async {
        let serializer = DiskMutationSerializer<String>()
        do {
            try await serializer.run(key: "boom") {
                throw NSError(domain: "TestError", code: 42)
            }
            XCTFail("Expected error to be propagated")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "TestError")
            XCTAssertEqual(error.code, 42)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_serializer_clearsKeyAfterCompletion() async throws {
        // After an operation completes, a new call with the same key
        // should start a fresh task (not reuse the previous result).
        let serializer = DiskMutationSerializer<String>()
        let counter = Counter()

        try await serializer.run(key: "x") { await counter.increment() }
        // Give the deferred clear() a moment to run.
        try await Task.sleep(nanoseconds: 20_000_000)
        try await serializer.run(key: "x") { await counter.increment() }

        let final = await counter.value
        XCTAssertEqual(final, 2)
    }

    // MARK: - ModelIntegrity

    func test_modelIntegrity_recordAndVerifyRoundTrip() throws {
        let tmpDir = makeTempDir()
        let modelURL = tmpDir.appendingPathComponent("model.bin")
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: modelURL)

        // Record creates the sidecar.
        try ModelIntegrity.record(at: modelURL)
        let sidecar = modelURL.appendingPathExtension("audiowhisper-integrity")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecar.path))

        // Verify succeeds against a matching file.
        XCTAssertNoThrow(try ModelIntegrity.verify(at: modelURL))
    }

    func test_modelIntegrity_detectsTamper() throws {
        let tmpDir = makeTempDir()
        let modelURL = tmpDir.appendingPathComponent("model.bin")
        try Data([0x01, 0x02, 0x03, 0x04]).write(to: modelURL)

        try ModelIntegrity.record(at: modelURL)

        // Mutate the file contents.
        try Data([0x09, 0x09, 0x09, 0x09]).write(to: modelURL)

        XCTAssertThrowsError(try ModelIntegrity.verify(at: modelURL)) { error in
            guard case ModelIntegrityError.mismatch = error else {
                XCTFail("Expected ModelIntegrityError.mismatch, got \(error)")
                return
            }
        }
    }

    func test_modelIntegrity_trustOnFirstUseWritesSidecar() throws {
        // No sidecar yet → verify() should record one and succeed.
        let tmpDir = makeTempDir()
        let modelURL = tmpDir.appendingPathComponent("model.bin")
        try Data([0xAA, 0xBB]).write(to: modelURL)

        let sidecar = modelURL.appendingPathExtension("audiowhisper-integrity")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path))

        XCTAssertNoThrow(try ModelIntegrity.verify(at: modelURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sidecar.path),
                      "Trust-on-first-use should persist a sidecar")

        // Second verify should now compare against the persisted hash.
        XCTAssertNoThrow(try ModelIntegrity.verify(at: modelURL))
    }

    func test_modelIntegrity_sha256IsStable() throws {
        // Same bytes → same hash, regardless of how many times we call.
        let tmpDir = makeTempDir()
        let modelURL = tmpDir.appendingPathComponent("model.bin")
        let bytes = Data(repeating: 0x42, count: 200_000) // 200KB to exercise chunk loop
        try bytes.write(to: modelURL)

        let a = try ModelIntegrity.sha256(of: modelURL)
        let b = try ModelIntegrity.sha256(of: modelURL)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 64, "SHA-256 hex digest should be 64 chars")
    }

    func test_modelIntegrity_quietVerifyReturnsFalseOnMismatch() throws {
        let tmpDir = makeTempDir()
        let modelURL = tmpDir.appendingPathComponent("model.bin")
        try Data([0x01]).write(to: modelURL)
        try ModelIntegrity.record(at: modelURL)
        try Data([0x02]).write(to: modelURL)

        XCTAssertFalse(ModelIntegrity.quietVerify(at: modelURL))
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DiskMutationSerializerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}

/// Sendable counter for cross-task accumulation in tests.
private actor Counter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}
