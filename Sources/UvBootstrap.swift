import Foundation

enum UvError: Error, LocalizedError {
    case uvNotFound
    case uvTooOld(found: String, required: String)
    case pythonNotUsable(String)
    case venvCreationFailed(String)
    case syncFailed(String)

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
        }
    }
}

struct UvBootstrap {
    static let minUvVersion = "0.8.5"
    static let defaultPythonVersion = "3.11"

    // Where we keep the app-managed project (contains pyproject + .venv)
    static func projectDir() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioWhisper", isDirectory: true)
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
        // Bundled at bin/uv
        if let resURL = Bundle.main.resourceURL {
            let url = resURL.appendingPathComponent("bin/uv")
            if FileManager.default.isExecutableFile(atPath: url.path) {
                if let ver = try? uvVersion(at: url) {
                    if isVersion(ver, greaterOrEqualThan: minUvVersion) { return url }
                    foundButOld = foundButOld ?? (url, ver)
                }
            }
        }
        // Per-user tools dir
        if let toolsURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
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
    static func ensureVenv(userPython: String? = nil, log: ((String)->Void)? = nil) throws -> URL {
        let uv = try findUv()
        let proj = try projectDir()

        let fm = FileManager.default
        // Copy pyproject.toml and uv.lock from bundle to project dir (if present / newer)
        try copyProjectFilesIfNeeded(to: proj)

        // Ensure .venv exists using specified Python (or default)
        let venvDir = proj.appendingPathComponent(".venv", isDirectory: true)
        if !fm.fileExists(atPath: venvDir.path) {
            let pythonSpecifier: String = (userPython?.isEmpty == false) ? userPython! : defaultPythonVersion
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

    // Copy pyproject.toml and uv.lock from bundle to per-user project dir
    private static func copyProjectFilesIfNeeded(to proj: URL) throws {
        guard let res = Bundle.main.resourceURL else { return }
        let fm = FileManager.default
        // Support both flattened and nested resource layouts for pyproject.toml only.
        // We intentionally do NOT copy a bundled uv.lock to avoid mismatches.
        let pyCandidates = [res.appendingPathComponent("pyproject.toml"), res.appendingPathComponent("Resources/pyproject.toml")]
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
        do { try p.run() } catch { return ("", String(describing: error), 1) }
        p.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
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
        do { try p.run() } catch { return ("", String(describing: error), 1) }
        p.waitUntilExit()
        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (out, err, p.terminationStatus)
    }

    private static func copyIfDifferent(src: URL, dst: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: dst.path) {
            let sAttr = try fm.attributesOfItem(atPath: src.path)
            let dAttr = try fm.attributesOfItem(atPath: dst.path)
            let sSize = (sAttr[.size] as? NSNumber)?.intValue ?? -1
            let dSize = (dAttr[.size] as? NSNumber)?.intValue ?? -2
            if sSize == dSize { return }
            try fm.removeItem(at: dst)
        }
        try fm.copyItem(at: src, to: dst)
    }
}
