import Foundation
import os.log

internal enum MLDaemonError: Error, LocalizedError {
    case scriptNotFound
    case daemonUnavailable(String)
    case invalidResponse(String)
    case remoteError(String)
    case restartLimitReached
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "ml_daemon.py could not be found"
        case .daemonUnavailable(let reason):
            return "ML daemon unavailable: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid response from ML daemon: \(reason)"
        case .remoteError(let message):
            return "ML daemon error: \(message)"
        case .restartLimitReached:
            return "ML daemon restart limit reached"
        case .writeFailed:
            return "Failed to write request to ML daemon"
        }
    }
}

internal actor MLDaemonManager {
    static let shared = MLDaemonManager()

    private struct PendingRequest {
        let completion: (Result<Data, Error>) -> Void
    }

    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "MLDaemon")
    private let maxRestartAttempts = 3

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var pending: [Int: PendingRequest] = [:]
    private var nextRequestID: Int = 1
    private var restartAttempts: Int = 0
    private var isShuttingDown = false
    private var pythonExecutable: URL?
    private var scriptLocation: URL?
#if DEBUG
    private var testResponder: ((String, [String: Any]) throws -> Any)?
#endif

    deinit {
        Task { [weak self] in await self?.shutdown() }
    }

    // MARK: - Public API

    func transcribe(repo: String, pcmPath: String) async throws -> String {
        struct TranscribeResult: Decodable { let success: Bool; let text: String; let error: String? }
        let result: TranscribeResult = try await sendRequest(
            method: "transcribe",
            params: ["repo": repo, "pcm_path": pcmPath]
        )
        guard result.success else { throw MLDaemonError.remoteError(result.error ?? "Transcription failed") }
        return result.text
    }

    func correct(repo: String, text: String, prompt: String?) async throws -> String {
        struct CorrectionResult: Decodable { let success: Bool; let text: String; let error: String? }
        var params: [String: Any] = ["repo": repo, "text": text]
        if let prompt = prompt { params["prompt"] = prompt }
        let result: CorrectionResult = try await sendRequest(method: "correct", params: params)
        guard result.success else { throw MLDaemonError.remoteError(result.error ?? "Correction failed") }
        return result.text
    }

    func warmup(type: String, repo: String) async throws {
        struct WarmupResult: Decodable { let success: Bool? }
        _ = try await sendRequest(method: "warmup", params: ["type": type, "repo": repo]) as WarmupResult
    }

    func ping() async -> Bool {
        struct PingResult: Decodable { let pong: Bool }
        do {
            let result: PingResult = try await sendRequest(method: "ping", params: [:])
            return result.pong
        } catch {
            logger.error("Ping failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Core JSON-RPC plumbing

    private func sendRequest<Response: Decodable>(method: String, params: [String: Any]) async throws -> Response {
#if DEBUG
        if let testResponder {
            let resultObject = try testResponder(method, params)
            let data = try JSONSerialization.data(withJSONObject: resultObject, options: [])
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw MLDaemonError.invalidResponse(error.localizedDescription)
            }
        }
#endif
        try ensureDaemonRunning()

        let requestID = nextRequestID
        nextRequestID += 1

        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": method
        ]
        if !params.isEmpty {
            payload["params"] = params
        }

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let writer = stdinPipe?.fileHandleForWriting else {
            throw MLDaemonError.daemonUnavailable("stdin unavailable")
        }

        writer.write(data)
        writer.write(Data([0x0a])) // newline

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Response, Error>) in
            pending[requestID] = PendingRequest { result in
                switch result {
                case .success(let responseData):
                    do {
                        let decoded = try JSONDecoder().decode(Response.self, from: responseData)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: MLDaemonError.invalidResponse(error.localizedDescription))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func handle(line: String) {
        guard let data = line.data(using: .utf8) else {
            logger.error("Failed to decode daemon line")
            return
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let id = json["id"] as? Int
        else {
            logger.error("Malformed JSON-RPC response")
            return
        }

        guard let pendingRequest = pending.removeValue(forKey: id) else {
            logger.error("No pending request for id \(id, privacy: .public)")
            return
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            pendingRequest.completion(.failure(MLDaemonError.remoteError(message)))
            return
        }

        guard let result = json["result"] else {
            pendingRequest.completion(.failure(MLDaemonError.invalidResponse("Missing result")))
            return
        }

        do {
            let resultData = try JSONSerialization.data(withJSONObject: result, options: [])
            pendingRequest.completion(.success(resultData))
        } catch {
            pendingRequest.completion(.failure(MLDaemonError.invalidResponse(error.localizedDescription)))
        }
    }

    // MARK: - Process lifecycle

    private func ensureDaemonRunning() throws {
        if let process, process.isRunning { return }
        guard !isShuttingDown else { throw MLDaemonError.daemonUnavailable("shutting down") }
        guard restartAttempts < maxRestartAttempts else { throw MLDaemonError.restartLimitReached }
        try startProcess(isRestart: false)
    }

    private func startProcess(isRestart: Bool) throws {
        let python = try resolvedPython()
        let script = try resolvedScript()

        if isRestart { restartAttempts += 1 } else { restartAttempts = 0 }
        if restartAttempts > maxRestartAttempts { throw MLDaemonError.restartLimitReached }

        let proc = Process()
        proc.executableURL = python
        proc.arguments = [script.path]
        proc.environment = ProcessInfo.processInfo.environment.merging(["PYTHONUNBUFFERED": "1"]) { _, new in new }

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        proc.terminationHandler = { [weak self] process in
            Task { await self?.processTerminated(exitCode: process.terminationStatus) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let message = String(decoding: data, as: UTF8.self)
            self?.logger.error("ml_daemon stderr: \(message, privacy: .public)")
        }

        do {
            try proc.run()
        } catch {
            throw MLDaemonError.daemonUnavailable("Failed to start process: \(error.localizedDescription)")
        }

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout
        stderrPipe = stderr
        isShuttingDown = false
        startStdoutReader(pipe: stdout)
    }

    private func startStdoutReader(pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") {
                Task { await self?.handle(line: String(line)) }
            }
        }
    }

    private func processTerminated(exitCode: Int32) async {
        logger.error("ml_daemon exited with code \(exitCode)")
        closePipes()

        if isShuttingDown {
            process = nil
            return
        }

        completeAllPending(with: MLDaemonError.daemonUnavailable("exited (\(exitCode))"))
        process = nil

        guard restartAttempts < maxRestartAttempts else { return }

        do {
            try startProcess(isRestart: true)
        } catch {
            logger.error("Failed to restart ml_daemon: \(error.localizedDescription)")
            completeAllPending(with: error)
        }
    }

    private func closePipes() {
        stdinPipe?.fileHandleForWriting.closeFile()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe?.fileHandleForReading.closeFile()
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.closeFile()
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    func shutdown() async {
        isShuttingDown = true
        closePipes()
        process?.terminate()
        process = nil
        completeAllPending(with: MLDaemonError.daemonUnavailable("shutdown"))
    }

    private func completeAllPending(with error: Error) {
        for (_, pendingRequest) in pending {
            pendingRequest.completion(.failure(error))
        }
        pending.removeAll()
    }

    // MARK: - Helpers

    private func resolvedPython() throws -> URL {
        if let pythonExecutable { return pythonExecutable }
        let url = try UvBootstrap.ensureVenv(userPython: nil)
        pythonExecutable = url
        return url
    }

    private func resolvedScript() throws -> URL {
        if let scriptLocation { return scriptLocation }

        let fm = FileManager.default
        
        // Try Bundle.main first (for .app bundles built with Xcode)
        if let bundled = Bundle.main.url(forResource: "ml_daemon", withExtension: "py") {
            scriptLocation = bundled
            return bundled
        }
        
        // Try SwiftPM resource bundle (AudioWhisper_AudioWhisper.bundle)
        if let resourceBundleURL = Bundle.main.url(forResource: "AudioWhisper_AudioWhisper", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let bundled = resourceBundle.url(forResource: "ml_daemon", withExtension: "py") {
            scriptLocation = bundled
            return bundled
        }

        // Dev fallback - running from source directory
        let devPath = "\(fm.currentDirectoryPath)/Sources/ml_daemon.py"
        if fm.fileExists(atPath: devPath) {
            let url = URL(fileURLWithPath: devPath)
            scriptLocation = url
            return url
        }

        throw MLDaemonError.scriptNotFound
    }
}

#if DEBUG
internal extension MLDaemonManager {
    func setTestResponder(_ responder: ((String, [String: Any]) throws -> Any)?) {
        testResponder = responder
    }

    /// Allows tests to bypass the default Python resolution and bundled script lookup.
    func setTestOverrides(python: URL?, script: URL?) async {
        pythonExecutable = python
        scriptLocation = script
    }

    /// Resets state for isolation between tests, ensuring processes are terminated and overrides cleared.
    func resetForTesting() async {
        await shutdown()
        pythonExecutable = nil
        scriptLocation = nil
        restartAttempts = 0
        isShuttingDown = false
        testResponder = nil
    }
}
#endif
