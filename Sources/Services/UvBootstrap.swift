import Foundation
import CryptoKit

internal enum UvError: Error, LocalizedError {
    case uvNotFound
    case uvTooOld(found: String, required: String)
    case pythonNotUsable(String)
    case venvCreationFailed(String)
    case syncFailed(String)
    case bundledBinaryTampered(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .uvNotFound:
            return "uv not found. Install with: brew install uv — or bundle an arm64 uv at Sources/Resources/bin/uv."
        case let .uvTooOld(found, required):
            return "uv version \(found) is too old; require \(required)+"
        case .pythonNotUsable(let msg):
            return "Python not usable: \(msg)"
        case .venvCreationFailed(let msg):
            return "Failed to create venv: \(msg)"
        case .syncFailed(let msg):
            return "Failed to sync Python deps: \(msg)"
        case let .bundledBinaryTampered(expected, actual):
            return "Bundled uv binary failed integrity check.\n  expected sha256: \(expected)\n  actual sha256:   \(actual)\nReinstall AudioWhisper from a trusted source."
        }
    }
}

/// Serializes venv-mutating operations so two callers (e.g. ParakeetService and
/// MLXCorrectionService racing at app launch) can't tread on each other.
internal actor VenvSerializer {
    static let shared = VenvSerializer()
    private var uvVerified = false

    /// Serialize an async, throwing operation. Two concurrent callers will be
    /// queued by the actor so neither can observe the venv mid-mutation.
    func run<T>(_ op: () async throws -> T) async rethrows -> T {
        try await op()
    }

    /// Atomically claims the right to perform bundled-uv verification once
    /// per app launch. Returns true on the FIRST call and false thereafter.
    func claimVerification() -> Bool {
        if uvVerified { return false }
        uvVerified = true
        return true
    }

    /// Test-only reset to force re-verification on next call.
    func resetVerificationForTesting() {
        uvVerified = false
    }
}

private class BundleFinder {}

internal struct UvBootstrap {
    static let minUvVersion = "0.8.5"
    static let defaultPythonVersion = "3.11"

    /// Safe accessor for the SPM module bundle that returns nil instead of crashing
    /// when the bundle is not found (e.g., when built with build.sh instead of SPM)
    private static var moduleBundle: Bundle? {
        let bundleName = "AudioWhisper_AudioWhisper"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
        ]
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        return nil
    }

    // Where we keep the app-managed project (contains pyproject + .venv)
    static func projectDir() throws -> URL {
        let fm = FileManager.default
        let appSupportBase = try applicationSupportBaseDirectory()
        let appSupport = appSupportBase.appendingPathComponent("AudioWhisper", isDirectory: true)
        if !fm.fileExists(atPath: appSupport.path) {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        let proj = appSupport.appendingPathComponent("python_project", isDirectory: true)
        if !fm.fileExists(atPath: proj.path) {
            try fm.createDirectory(at: proj, withIntermediateDirectories: true)
        }
        return proj
    }

    // Find uv or throw precise error (too old vs not found)
    static func findUv() throws -> URL {
        var foundButOld: (URL, String)? = nil
        // PATH
        if let pathUv = which("uv") {
            let url = URL(fileURLWithPath: pathUv)
            if let ver = try? uvVersion(at: url) {
                if isVersion(ver, greaterOrEqualThan: minUvVersion) { return url }
                foundButOld = (url, ver)
            }
        }
        // Bundled uv - check multiple locations for different build methods
        // Release build (build.sh): Contents/Resources/bin/uv
        // Xcode/SPM build: AudioWhisper_AudioWhisper.bundle/Contents/Resources/Resources/bin/uv
        let bundleCandidates: [URL] = [
            Bundle.main.resourceURL,
            moduleBundle?.resourceURL
        ].compactMap { $0 }

        for resURL in bundleCandidates {
            let paths = [
                resURL.appendingPathComponent("bin/uv"),
                resURL.appendingPathComponent("Resources/bin/uv")
            ]
            for url in paths {
                if FileManager.default.isExecutableFile(atPath: url.path) {
                    if let ver = try? uvVersion(at: url) {
                        if isVersion(ver, greaterOrEqualThan: minUvVersion) { return url }
                        foundButOld = foundButOld ?? (url, ver)
                    }
                }
            }
        }
        // Per-user tools dir
        if let toolsURL = try? applicationSupportBaseDirectory()
            .appendingPathComponent("AudioWhisper/bin", isDirectory: true) {
            let url = toolsURL.appendingPathComponent("uv")
            if FileManager.default.isExecutableFile(atPath: url.path) {
                if let ver = try? uvVersion(at: url) {
                    if isVersion(ver, greaterOrEqualThan: minUvVersion) { return url }
                    foundButOld = foundButOld ?? (url, ver)
                }
            }
        }
        if let (_, ver) = foundButOld { throw UvError.uvTooOld(found: ver, required: minUvVersion) }
        throw UvError.uvNotFound
    }

    // Ensure project exists and dependencies are synced with uv. Returns path to project .venv python.
    // If userPython is nil, we let uv provision or use its managed interpreter (via --python 3.x)
    //
    // Serialized through VenvSerializer so concurrent callers (Parakeet + MLX warmup
    // at app launch, etc.) don't race each other while creating the venv or running
    // `uv sync` on the same project directory.
    static func ensureVenv(userPython: String? = nil, log: ((String)->Void)? = nil) async throws -> URL {
        try await VenvSerializer.shared.run {
            let uv = try findUv()
            // Verify the bundled uv binary the first time we pick it up. Verification
            // is a no-op when no SHA was stamped at build time (developer/SPM builds).
            try await verifyBundledUvIfNeeded(uvURL: uv)
            let proj = try projectDir()

            let fm = FileManager.default
            // Copy pyproject.toml and uv.lock from bundle to project dir (if present / newer)
            try copyProjectFilesIfNeeded(to: proj)

            // Ensure .venv exists using specified Python (or default)
            let venvDir = proj.appendingPathComponent(".venv", isDirectory: true)
            if !fm.fileExists(atPath: venvDir.path) {
                let pythonSpecifier = userPython.flatMap { $0.isEmpty ? nil : $0 } ?? defaultPythonVersion
                log?("Creating project .venv with Python \(pythonSpecifier)…")
                let (out, err, status) = runInDir(uv.path, ["venv", "--python", pythonSpecifier], cwd: proj)
                if status != 0 { throw UvError.venvCreationFailed(err.isEmpty ? out : err) }
            }

            // Run uv sync in project directory. We do not enforce --frozen so that
            // a stale lock can be updated to match the bundled pyproject.toml.
            log?("Syncing project dependencies via uv sync…")
            let (out, err, status) = runInDir(uv.path, ["sync"], cwd: proj)
            if status != 0 { throw UvError.syncFailed(err.isEmpty ? out : err) }

            // Return the project venv python
            let candidates = [
                proj.appendingPathComponent(".venv/bin/python3").path,
                proj.appendingPathComponent(".venv/bin/python").path
            ]
            for c in candidates { if fm.isExecutableFile(atPath: c) { return URL(fileURLWithPath: c) } }
            throw UvError.pythonNotUsable("project venv python not found")
        }
    }

    /// Verifies the bundled uv binary against the SHA-256 stamped at build time.
    /// Runs at most once per app launch. If no hash was stamped (developer build
    /// without `Sources/Resources/bin/uv`, or `swift run`), verification is a no-op.
    /// Only the bundled binary is checked — Homebrew or user-installed `uv` is trusted.
    private static func verifyBundledUvIfNeeded(uvURL: URL) async throws {
        // Only the first caller this launch performs the actual check.
        let shouldVerify = await VenvSerializer.shared.claimVerification()
        guard shouldVerify else { return }

        let expected = VersionInfo.bundledUvSha256
        // Empty or unsubstituted placeholder => no hash available; skip verification.
        guard !expected.isEmpty, expected != "BUNDLED_UV_SHA256_PLACEHOLDER" else { return }

        // Only verify when we actually picked the bundled uv (not a Homebrew uv on PATH).
        guard isBundledUv(uvURL) else { return }

        let data: Data
        do {
            data = try Data(contentsOf: uvURL, options: .mappedIfSafe)
        } catch {
            throw UvError.pythonNotUsable("could not read bundled uv: \(error.localizedDescription)")
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if actual.lowercased() != expected.lowercased() {
            // Reset the flag so a subsequent attempt (e.g. after a fresh install)
            // can re-verify rather than silently treating the binary as good.
            await VenvSerializer.shared.resetVerificationForTesting()
            throw UvError.bundledBinaryTampered(expected: expected.lowercased(), actual: actual)
        }
    }

    /// Returns true if the given uv URL points at the binary we bundle inside
    /// the app — used to scope SHA verification to our own copy only.
    private static func isBundledUv(_ url: URL) -> Bool {
        let bundleCandidates: [URL] = [
            Bundle.main.resourceURL,
            moduleBundle?.resourceURL
        ].compactMap { $0 }
        for resURL in bundleCandidates {
            let paths = [
                resURL.appendingPathComponent("bin/uv"),
                resURL.appendingPathComponent("Resources/bin/uv")
            ]
            if paths.contains(where: { $0.standardizedFileURL.path == url.standardizedFileURL.path }) {
                return true
            }
        }
        return false
    }

    // Copy pyproject.toml and uv.lock from bundle to per-user project dir
    /// Check if the Python environment is ready (venv exists with python executable)
    static func isEnvReady() async -> Bool {
        do {
            let proj = try projectDir()
            let venvPython = proj.appendingPathComponent(".venv/bin/python3")
            return FileManager.default.isExecutableFile(atPath: venvPython.path)
        } catch {
            return false
        }
    }

    private static func copyProjectFilesIfNeeded(to proj: URL) throws {
        let fm = FileManager.default
        // Check both Bundle.main (build.sh) and SPM module bundle (Xcode builds)
        let resourceURLs = [Bundle.main.resourceURL, moduleBundle?.resourceURL].compactMap { $0 }

        // Support both flattened and nested resource layouts for pyproject.toml only.
        // We intentionally do NOT copy a bundled uv.lock to avoid mismatches.
        var pyCandidates: [URL] = []
        for res in resourceURLs {
            pyCandidates.append(res.appendingPathComponent("pyproject.toml"))
            pyCandidates.append(res.appendingPathComponent("Resources/pyproject.toml"))
        }

        if let src = pyCandidates.first(where: { fm.fileExists(atPath: $0.path) }) {
            let dest = proj.appendingPathComponent("pyproject.toml")
            try copyIfDifferent(src: src, dst: dest)
        }
    }

    // MARK: - Utilities

    private static func which(_ cmd: String) -> String? {
        let (out, _, status) = run("/usr/bin/which", [cmd])
        guard status == 0 else { return nil }
        let path = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    // Allow tests to override the base Application Support directory via env var
    private static func applicationSupportBaseDirectory() throws -> URL {
        let fm = FileManager.default
        if let override = ProcessInfo.processInfo.environment["AUDIOWHISPER_APP_SUPPORT_DIR"], !override.isEmpty {
            let url = URL(fileURLWithPath: override, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
            return url
        }
        return try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    private static func uvVersion(at url: URL) throws -> String {
        let (out, err, status) = run(url.path, ["--version"])
        guard status == 0 else { throw UvError.syncFailed(err.isEmpty ? out : err) }
        let s = out.trimmingCharacters(in: .whitespacesAndNewlines)
        // Common formats:
        //  - "uv 0.8.5 (ce3728681 2025-08-05)"
        //  - "uv 0.8.5"
        //  - "0.8.5"
        if let range = s.range(of: #"\d+\.\d+\.\d+([\-\+][A-Za-z0-9\.\-]+)?"#, options: .regularExpression) {
            return String(s[range])
        }
        let comps = s.split(separator: " ")
        if comps.count >= 2 && comps[0].lowercased() == "uv" { return String(comps[1]) }
        return s
    }

    private static func isVersion(_ v: String, greaterOrEqualThan min: String) -> Bool {
        func parse(_ s: String) -> [Int] { s.split(separator: ".").compactMap { Int($0) } }
        let a = parse(v)
        let b = parse(min)
        for i in 0..<max(a.count, b.count) {
            let ai = i < a.count ? a[i] : 0
            let bi = i < b.count ? b[i] : 0
            if ai != bi { return ai > bi }
        }
        return true
    }

    @discardableResult
    private static func run(_ cmd: String, _ args: [String]) -> (String, String, Int32) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        do {
            try p.run()
        } catch {
            // Close file handles to prevent resource leak
            try? outPipe.fileHandleForReading.close()
            try? errPipe.fileHandleForReading.close()
            return ("", String(describing: error), 1)
        }
        p.waitUntilExit()
        // Read output before closing handles
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        // Explicitly close file handles to ensure immediate resource cleanup
        try? outPipe.fileHandleForReading.close()
        try? errPipe.fileHandleForReading.close()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return (out, err, p.terminationStatus)
    }

    @discardableResult
    private static func runInDir(_ cmd: String, _ args: [String], cwd: URL) -> (String, String, Int32) {
        let p = Process()
        p.currentDirectoryURL = cwd
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        do {
            try p.run()
        } catch {
            // Close file handles to prevent resource leak
            try? outPipe.fileHandleForReading.close()
            try? errPipe.fileHandleForReading.close()
            return ("", String(describing: error), 1)
        }
        p.waitUntilExit()
        // Read output before closing handles
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        // Explicitly close file handles to ensure immediate resource cleanup
        try? outPipe.fileHandleForReading.close()
        try? errPipe.fileHandleForReading.close()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return (out, err, p.terminationStatus)
    }

    private static func copyIfDifferent(src: URL, dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            let sAttr = try fm.attributesOfItem(atPath: src.path)
            let dAttr = try fm.attributesOfItem(atPath: dst.path)
            let sSize = (sAttr[.size] as? NSNumber)?.intValue ?? -1
            let dSize = (dAttr[.size] as? NSNumber)?.intValue ?? -2
            // Also compare modification dates, not just size
            // If pyproject.toml changes but stays same size, we'd miss the update
            let sDate = sAttr[.modificationDate] as? Date
            let dDate = dAttr[.modificationDate] as? Date
            let sameSize = sSize == dSize
            let srcNotNewer: Bool
            if let sourceDate = sDate, let destDate = dDate {
                srcNotNewer = sourceDate <= destDate
            } else {
                srcNotNewer = false
            }
            if sameSize && srcNotNewer { return }
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }
}
