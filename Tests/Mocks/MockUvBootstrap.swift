import Foundation
@testable import AudioWhisper

/// Mock for UvBootstrap to avoid actual Python environment operations in tests
enum MockUvBootstrap {
    // MARK: - Configurable Behavior

    nonisolated(unsafe) static var shouldSucceed = true
    nonisolated(unsafe) static var errorToThrow: UvError?
    nonisolated(unsafe) static var mockPythonPath = "/usr/bin/python3"

    // MARK: - Call Tracking

    nonisolated(unsafe) static var ensureVenvCallCount = 0
    nonisolated(unsafe) static var findUvCallCount = 0
    nonisolated(unsafe) static var projectDirCallCount = 0

    // MARK: - Mock Methods

    static func ensureVenv(userPython: String? = nil, log: ((String) -> Void)? = nil) async throws -> URL {
        ensureVenvCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        if !shouldSucceed {
            throw UvError.venvCreationFailed("Mock failure")
        }

        return URL(fileURLWithPath: mockPythonPath)
    }

    static func findUv() throws -> URL {
        findUvCallCount += 1

        if let error = errorToThrow {
            throw error
        }

        if !shouldSucceed {
            throw UvError.uvNotFound
        }

        return URL(fileURLWithPath: "/usr/local/bin/uv")
    }

    static func projectDir() throws -> URL {
        projectDirCallCount += 1

        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("MockAudioWhisper/python_project")
    }

    // MARK: - Test Helpers

    static func reset() {
        shouldSucceed = true
        errorToThrow = nil
        mockPythonPath = "/usr/bin/python3"
        ensureVenvCallCount = 0
        findUvCallCount = 0
        projectDirCallCount = 0
    }

    static func setSuccess() {
        shouldSucceed = true
        errorToThrow = nil
    }

    static func setFailure(_ error: UvError) {
        shouldSucceed = false
        errorToThrow = error
    }
}
