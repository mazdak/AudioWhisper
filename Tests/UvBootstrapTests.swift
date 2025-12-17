import Foundation
import XCTest
@testable import AudioWhisper

final class UvBootstrapTests: XCTestCase {
    private var originalHome: String?
    private var originalPath: String?
    private var originalAppSupportOverride: String?
    private var tempHome: URL!
    private var tempAppSupport: URL!
    private var tempBin: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalHome = ProcessInfo.processInfo.environment["HOME"]
        originalPath = ProcessInfo.processInfo.environment["PATH"]
        originalAppSupportOverride = ProcessInfo.processInfo.environment["AUDIOWHISPER_APP_SUPPORT_DIR"]

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("UvBootstrapTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        tempHome = tempRoot
        tempAppSupport = tempRoot.appendingPathComponent("AppSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: tempAppSupport, withIntermediateDirectories: true)
        tempBin = tempRoot.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBin, withIntermediateDirectories: true)

        setenv("HOME", tempHome.path, 1)
        setenv("AUDIOWHISPER_APP_SUPPORT_DIR", tempAppSupport.path, 1)
        // Keep /usr/bin last so tools like /usr/bin/env remain reachable while excluding any real uv in default paths.
        setenv("PATH", "\(tempBin.path):/usr/bin", 1)
    }

    override func tearDownWithError() throws {
        if let originalHome {
            setenv("HOME", originalHome, 1)
        }
        if let originalPath {
            setenv("PATH", originalPath, 1)
        }
        if let originalAppSupportOverride {
            setenv("AUDIOWHISPER_APP_SUPPORT_DIR", originalAppSupportOverride, 1)
        } else {
            unsetenv("AUDIOWHISPER_APP_SUPPORT_DIR")
        }
        if let tempHome {
            try? FileManager.default.removeItem(at: tempHome)
        }
        try super.tearDownWithError()
    }

    func testFindUvThrowsWhenUvTooOld() throws {
        let uvURL = try writeUvStub(version: "0.8.4")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: uvURL.path))
        XCTAssertEqual(whichUVPath(), uvURL.path)

        XCTAssertThrowsError(try UvBootstrap.findUv()) { error in
            guard case let UvError.uvTooOld(found, required) = error else {
                return XCTFail("Expected uvTooOld, got \(error)")
            }
            XCTAssertEqual(found, "0.8.4")
            XCTAssertEqual(required, UvBootstrap.minUvVersion)
        }
    }

    func testFindUvFallsBackToUserToolsDirectory() throws {
        // No uv on PATH; add one under Application Support/AudioWhisper/bin/uv
        let toolsDir = tempAppSupport.appendingPathComponent("AudioWhisper/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: toolsDir, withIntermediateDirectories: true)

        let uvURL = toolsDir.appendingPathComponent("uv")
        try writeExecutable("#!/bin/bash\necho 'uv 0.9.0'\n", to: uvURL)

        let found = try UvBootstrap.findUv()
        XCTAssertEqual(found, uvURL)
    }

    func testEnsureVenvCreatesAndSyncsWithDefaultPython() throws {
        let logURL = tempHome.appendingPathComponent("uv_invocations.log")
        let uvURL = try writeUvStub(version: "0.8.6", logFile: logURL)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: uvURL.path))

        let project = try UvBootstrap.projectDir()
        // Pre-seed a minimal venv layout to avoid relying on the stub creating files.
        let pythonBin = project.appendingPathComponent(".venv/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: pythonBin, withIntermediateDirectories: true)
        let pythonFile = pythonBin.appendingPathComponent("python3")
        try "#!/bin/bash\necho python\n".write(to: pythonFile, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pythonFile.path)

        var logMessages: [String] = []
        let pythonURL: URL
        do {
            pythonURL = try UvBootstrap.ensureVenv(userPython: nil) { logMessages.append($0) }
        } catch {
            let binPath = project.appendingPathComponent(".venv/bin")
            let binContents = try? FileManager.default.contentsOfDirectory(atPath: binPath.path)
            let logContents = (try? String(contentsOf: logURL)) ?? "<empty>"
            let exists = FileManager.default.fileExists(atPath: binPath.path)
            let python3Exists = FileManager.default.isExecutableFile(atPath: binPath.appendingPathComponent("python3").path)
            XCTFail("ensureVenv threw \(error); project: \(project.path); binExists: \(exists); python3Exists: \(python3Exists); .venv/bin contents: \(binContents ?? []); log: \(logContents)")
            return
        }

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: pythonURL.path))
        XCTAssertTrue(pythonURL.path.hasSuffix(".venv/bin/python3"))
        XCTAssertEqual(logMessages.first, "Syncing project dependencies via uv sync…")
        XCTAssertEqual(logMessages.last, "Syncing project dependencies via uv sync…")

        let invocations = try String(contentsOf: logURL).split(separator: "\n")
        XCTAssertTrue(invocations.contains(where: { $0.contains("--version") }))
        XCTAssertTrue(
            invocations.contains(where: { $0.contains("venv --python \(UvBootstrap.defaultPythonVersion)") }) ||
            FileManager.default.fileExists(atPath: project.appendingPathComponent(".venv").path)
        )
        XCTAssertTrue(invocations.contains(where: { $0.contains("sync") }))
    }

    // MARK: - Helpers

    private func whichUVPath() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["uv"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @discardableResult
    private func writeUvStub(version: String, logFile: URL? = nil) throws -> URL {
        let uvURL = tempBin.appendingPathComponent("uv")
        var lines: [String] = ["#!/bin/bash"]
        lines.append("dir=\"$(pwd)\"")
        if let logFile {
            lines.append("echo \"$dir :: $*\" >> \"\(logFile.path)\"")
        }
        // Always ensure a minimal venv layout so tests remain deterministic
        lines.append("mkdir -p \"$dir/.venv/bin\"")
        lines.append("cat > \"$dir/.venv/bin/python3\" <<'PY'\n#!/bin/bash\necho python\nPY")
        lines.append("chmod +x \"$dir/.venv/bin/python3\"")
        lines.append("ln -sf python3 \"$dir/.venv/bin/python\"")
        lines.append("if [[ \"$1\" == \"--version\" ]]; then")
        lines.append("  echo 'uv \(version)'")
        lines.append("  exit 0")
        lines.append("fi")
        lines.append("if [[ \"$1\" == \"venv\" ]]; then")
        lines.append("  exit 0")
        lines.append("fi")
        lines.append("if [[ \"$1\" == \"sync\" ]]; then")
        lines.append("  exit 0")
        lines.append("fi")
        lines.append("echo 'unexpected args' >&2")
        lines.append("exit 1")

        try writeExecutable(lines.joined(separator: "\n") + "\n", to: uvURL)
        return uvURL
    }

    private func writeExecutable(_ contents: String, to url: URL) throws {
        let data = Data(contents.utf8)
        try data.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
