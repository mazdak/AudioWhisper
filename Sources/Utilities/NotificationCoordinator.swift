import Foundation

/// A coordinator for managing notification observers with automatic cleanup.
/// Provides a cleaner API than manually tracking NSObjectProtocol references.
@MainActor
final class NotificationCoordinator {
    private var observers: [Notification.Name: NSObjectProtocol] = [:]
    private var tasks: [Notification.Name: Task<Void, Never>] = [:]

    deinit {
        // Clean up any remaining observers
        // Note: This runs on whatever thread triggers deallocation
        let observersToRemove = observers.values
        for observer in observersToRemove {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Traditional Observer Pattern

    /// Adds an observer for a notification using the traditional closure-based API.
    /// The observer is automatically tracked and can be removed with `remove(for:)` or `removeAll()`.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - queue: The operation queue to run the handler on (defaults to main)
    ///   - handler: The closure to execute when the notification is received
    func observe(
        _ name: Notification.Name,
        queue: OperationQueue? = .main,
        handler: @escaping @Sendable (Notification) -> Void
    ) {
        // Remove existing observer for this name if any
        remove(for: name)

        let observer = NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: queue,
            using: handler
        )
        observers[name] = observer
    }

    /// Adds an observer that wraps the handler in a MainActor Task.
    /// Useful for observers that need to update UI state.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - handler: The async closure to execute on the MainActor
    func observeOnMainActor(
        _ name: Notification.Name,
        handler: @escaping @MainActor (Notification) async -> Void
    ) {
        observe(name, queue: .main) { notification in
            Task { @MainActor in
                await handler(notification)
            }
        }
    }

    // MARK: - Async Stream Pattern

    /// Starts observing a notification using async/await.
    /// The task runs until cancelled or the coordinator is deallocated.
    ///
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - handler: The async handler to execute for each notification
    func observeAsync(
        _ name: Notification.Name,
        handler: @escaping @MainActor @Sendable (Notification) async -> Void
    ) {
        // Cancel existing task for this name if any
        tasks[name]?.cancel()

        let task = Task { @MainActor in
            for await notification in NotificationCenter.default.notifications(named: name) {
                await handler(notification)
            }
        }
        tasks[name] = task
    }

    // MARK: - Cleanup

    /// Removes the observer for a specific notification name.
    func remove(for name: Notification.Name) {
        if let observer = observers.removeValue(forKey: name) {
            NotificationCenter.default.removeObserver(observer)
        }
        if let task = tasks.removeValue(forKey: name) {
            task.cancel()
        }
    }

    /// Removes all observers and cancels all tasks.
    func removeAll() {
        for observer in observers.values {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }

    // MARK: - Query

    /// Returns true if an observer exists for the given notification name.
    func isObserving(_ name: Notification.Name) -> Bool {
        observers[name] != nil || tasks[name] != nil
    }

    /// Returns the count of active observers.
    var observerCount: Int {
        observers.count + tasks.count
    }
}
