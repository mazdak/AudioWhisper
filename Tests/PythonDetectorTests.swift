import XCTest
@testable import AudioWhisper

final class PythonDetectorTests: XCTestCase {

    func testCheckPythonHasMLXReturnsTrueForExecutablePrintingOK() async throws {
        let tempDir = try temporaryDirectory()
        let scriptURL = tempDir.appendingPathComponent("python-stub")
        try writeExecutable(at: scriptURL, contents: "#!/bin/sh\necho \"OK\"\n")

        let hasMLX = await PythonDetector.checkPythonHasMLX(at: scriptURL.path)

        XCTAssertTrue(hasMLX)
    }

    func testCheckPythonHasMLXReturnsFalseForMissingExecutable() async {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nonexistent-python")

        let hasMLX = await PythonDetector.checkPythonHasMLX(at: missingPath.path)

        XCTAssertFalse(hasMLX)
    }

    func testFindViaWhichRespectsCustomPATH() async throws {
        let tempDir = try temporaryDirectory()
        let stubURL = tempDir.appendingPathComponent("python3")
        try writeExecutable(at: stubURL, contents: "#!/bin/sh\necho stub\n")

        let originalPath = getenv("PATH").flatMap { String(cString: $0) }
        setenv("PATH", "\(tempDir.path):\(originalPath ?? "")", 1)
        defer {
            if let originalPath {
                setenv("PATH", originalPath, 1)
            } else {
                unsetenv("PATH")
            }
        }

        let foundPath = await PythonDetector.findViaWhich()

        XCTAssertEqual(foundPath, stubURL.path)
    }

    func testFindPythonWithMLXPrefersLocalVirtualEnv() async throws {
        let tempDir = try temporaryDirectory()
        let originalDirectory = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer {
            FileManager.default.changeCurrentDirectoryPath(originalDirectory)
        }

        let venvPython = tempDir
            .appendingPathComponent(".venv")
            .appendingPathComponent("bin")
            .appendingPathComponent("python")
        try writeExecutable(at: venvPython, contents: "#!/bin/sh\necho \"OK\"\n")

        let found = await PythonDetector.findPythonWithMLX()

        // findPythonWithMLX returns relative path ".venv/bin/python" when found in current directory
        XCTAssertEqual(found, ".venv/bin/python")
    }

    // MARK: - Helpers

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeExecutable(at url: URL, contents: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.data(using: .utf8)?.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
