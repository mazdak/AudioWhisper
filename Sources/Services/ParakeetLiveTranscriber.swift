import Foundation
import os.log

internal actor ParakeetLiveTranscriber {
    static let shared = ParakeetLiveTranscriber()

    private struct Session {
        let repo: String
        let pcmURL: URL
        let outputHandle: FileHandle
        var bootstrapTask: Task<Void, Never>?
        var streamID: String?
        var startError: String?
        var isStopped = false
        var isPollingPartial = false
        var lastPollAt = Date.distantPast
        var lastPartialText = ""
    }

    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ParakeetLive")
    private let daemon = MLDaemonManager.shared
    private let partialPollInterval: TimeInterval = 1.2
    private var session: Session?

    func startIfNeeded(repo: String) async {
        guard session == nil else { return }

        let pcmURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("parakeet_live_\(UUID().uuidString).raw")
        guard FileManager.default.createFile(atPath: pcmURL.path, contents: nil) else {
            logger.error("Failed to create live PCM file")
            return
        }

        do {
            let outputHandle = try FileHandle(forWritingTo: pcmURL)
            var newSession = Session(repo: repo, pcmURL: pcmURL, outputHandle: outputHandle)

            let pcmPath = pcmURL.path
            newSession.bootstrapTask = Task {
                do {
                    _ = try UvBootstrap.ensureVenv(userPython: nil)
                    let streamID = try await self.daemon.parakeetStreamStart(repo: repo, pcmPath: pcmPath)
                    self.markStreamReady(streamID: streamID, pcmPath: pcmPath)
                } catch {
                    self.markStreamStartFailed(message: error.localizedDescription, pcmPath: pcmPath)
                }
            }
            session = newSession
        } catch {
            logger.error("Failed to open live PCM output: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: pcmURL)
        }
    }

    func appendPCMChunk(_ chunk: Data) async {
        guard !chunk.isEmpty else { return }
        guard let current = session else { return }

        do {
            try current.outputHandle.write(contentsOf: chunk)
        } catch {
            logger.error("Failed to write live PCM chunk: \(error.localizedDescription)")
            return
        }

        schedulePartialPollIfNeeded()
    }

    func stopCapture() async {
        guard var current = session else { return }
        guard !current.isStopped else { return }
        current.outputHandle.synchronizeFile()
        current.outputHandle.closeFile()
        current.isStopped = true
        session = current
    }

    func finalizeIfAvailable(expectedRepo: String) async -> String? {
        guard let current = session else { return nil }
        guard current.repo == expectedRepo else {
            await cancel()
            return nil
        }

        await stopCapture()
        await current.bootstrapTask?.value

        guard let ready = session else { return nil }
        guard let streamID = ready.streamID else {
            if let startError = ready.startError {
                logger.error("Live stream was not ready: \(startError)")
            }
            await cleanupCurrentSession(abortRemote: false)
            return nil
        }

        do {
            let text = try await daemon.parakeetStreamFinalize(streamID: streamID)
            await cleanupCurrentSession(abortRemote: false)
            return text
        } catch {
            logger.error("Live stream finalize failed: \(error.localizedDescription)")
            await cleanupCurrentSession(abortRemote: true)
            return nil
        }
    }

    func cancel() async {
        await cleanupCurrentSession(abortRemote: true)
    }

    private func markStreamReady(streamID: String, pcmPath: String) {
        guard var current = session else { return }
        guard current.pcmURL.path == pcmPath else { return }
        current.streamID = streamID
        current.startError = nil
        session = current
    }

    private func markStreamStartFailed(message: String, pcmPath: String) {
        guard var current = session else { return }
        guard current.pcmURL.path == pcmPath else { return }
        current.startError = message
        session = current
    }

    private func schedulePartialPollIfNeeded() {
        guard var current = session else { return }
        guard let streamID = current.streamID else { return }

        let now = Date()
        guard !current.isPollingPartial else { return }
        guard now.timeIntervalSince(current.lastPollAt) >= partialPollInterval else { return }

        current.isPollingPartial = true
        current.lastPollAt = now
        session = current

        Task {
            do {
                let text = try await self.daemon.parakeetStreamUpdate(streamID: streamID)
                self.handlePartialPollSuccess(text: text)
            } catch {
                self.handlePartialPollFailure(error: error)
            }
        }
    }

    private func handlePartialPollSuccess(text: String) {
        guard var current = session else { return }
        current.isPollingPartial = false

        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            session = current
            return
        }
        guard normalized != current.lastPartialText else {
            session = current
            return
        }

        current.lastPartialText = normalized
        session = current

        NotificationCenter.default.post(
            name: .transcriptionProgress,
            object: displaySnippet(for: normalized),
            userInfo: ["aw_partial": true]
        )
    }

    private func handlePartialPollFailure(error: Error) {
        guard var current = session else { return }
        current.isPollingPartial = false
        session = current
        logger.error("Live stream update failed: \(error.localizedDescription)")
    }

    private func cleanupCurrentSession(abortRemote: Bool) async {
        guard let current = session else { return }
        session = nil

        if !current.isStopped {
            current.outputHandle.synchronizeFile()
            current.outputHandle.closeFile()
        }

        if abortRemote, let streamID = current.streamID {
            await daemon.parakeetStreamAbort(streamID: streamID)
        }

        try? FileManager.default.removeItem(at: current.pcmURL)
    }

    private func displaySnippet(for text: String) -> String {
        let limit = 96
        guard text.count > limit else { return text }
        return "…" + String(text.suffix(limit))
    }
}
