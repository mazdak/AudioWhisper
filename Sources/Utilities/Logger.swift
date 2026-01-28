import Foundation
import os.log

// Centralized logging for AudioWhisper
internal extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.audiowhisper.app"

    static let modelManager = Logger(subsystem: subsystem, category: "ModelManager")
    static let audioRecorder = Logger(subsystem: subsystem, category: "AudioRecorder")
    static let microphoneVolume = Logger(subsystem: subsystem, category: "MicrophoneVolume")
    static let speechToText = Logger(subsystem: subsystem, category: "SpeechToText")
    static let keychain = Logger(subsystem: subsystem, category: "Keychain")
    static let app = Logger(subsystem: subsystem, category: "App")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let dataManager = Logger(subsystem: subsystem, category: "DataManager")
    static let paste = Logger(subsystem: subsystem, category: "Paste")
    static let fileSystem = Logger(subsystem: subsystem, category: "FileSystem")
    static let uvBootstrap = Logger(subsystem: subsystem, category: "UvBootstrap")
    static let mlxModel = Logger(subsystem: subsystem, category: "MLXModel")
}

// MARK: - Logging Helpers

/// Executes a throwing operation and logs any error that occurs.
/// Returns nil if the operation fails (similar to try? but with logging).
internal func tryWithLogging<T>(
    _ operation: () throws -> T,
    logger: Logger,
    context: String
) -> T? {
    do {
        return try operation()
    } catch {
        logger.error("\(context): \(error.localizedDescription)")
        return nil
    }
}

/// Async version of tryWithLogging for async operations.
internal func tryWithLogging<T>(
    _ operation: () async throws -> T,
    logger: Logger,
    context: String
) async -> T? {
    do {
        return try await operation()
    } catch {
        logger.error("\(context): \(error.localizedDescription)")
        return nil
    }
}