import Foundation

/// Error thrown when an async operation times out
enum AsyncTimeoutError: Error, LocalizedError {
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .timedOut(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        }
    }
}

/// Wraps an async operation with a timeout.
/// If the operation doesn't complete within the timeout, throws `AsyncTimeoutError.timedOut`.
///
/// - Parameters:
///   - timeout: Maximum time to wait in seconds
///   - operation: The async operation to perform
/// - Returns: The result of the operation
/// - Throws: `AsyncTimeoutError.timedOut` if timeout expires, or any error from the operation
func withTimeout<T: Sendable>(
    _ timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw AsyncTimeoutError.timedOut(timeout)
        }

        // Wait for the first task to complete
        guard let result = try await group.next() else {
            throw AsyncTimeoutError.timedOut(timeout)
        }

        // Cancel the remaining task (either the timeout or the operation)
        group.cancelAll()
        return result
    }
}

/// Default timeout for network transcription requests (60 seconds)
let transcriptionNetworkTimeout: TimeInterval = 60

/// Default timeout for semantic correction requests (30 seconds)
let semanticCorrectionTimeout: TimeInterval = 30

// MARK: - Callback Bridge Utilities

/// A thread-safe wrapper that ensures a callback is only invoked once.
/// Useful when bridging callback-based APIs (like Alamofire) to Swift Concurrency,
/// where the callback might be called multiple times but continuation.resume() must only be called once.
final class OnceCallback<T>: @unchecked Sendable {
    private var hasBeenCalled = false
    private let lock = NSLock()
    private let handler: (Result<T, Error>) -> Void

    init(handler: @escaping (Result<T, Error>) -> Void) {
        self.handler = handler
    }

    /// Invokes the handler if it hasn't been called yet.
    /// Thread-safe: only the first call will execute the handler.
    func callOnce(_ result: Result<T, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !hasBeenCalled else { return }
        hasBeenCalled = true
        handler(result)
    }

    /// Convenience for success case
    func success(_ value: T) {
        callOnce(.success(value))
    }

    /// Convenience for failure case
    func failure(_ error: Error) {
        callOnce(.failure(error))
    }
}

/// Bridges a callback-based operation to Swift Concurrency with timeout support.
/// The callback wrapper ensures the continuation is resumed exactly once, even if
/// the underlying API calls the callback multiple times.
///
/// - Parameters:
///   - timeout: Maximum time to wait in seconds
///   - operation: A closure that receives a OnceCallback to signal completion
/// - Returns: The result from the callback
/// - Throws: `AsyncTimeoutError.timedOut` if timeout expires, or any error from the callback
func withCallbackBridge<T: Sendable>(
    timeout: TimeInterval,
    operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
) async throws -> T {
    try await withTimeout(timeout) {
        try await withCheckedThrowingContinuation { continuation in
            let callback = OnceCallback<T> { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            operation { result in
                callback.callOnce(result)
            }
        }
    }
}
