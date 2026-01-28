import AppKit

internal extension AppDelegate {
    /// Sets up notification observers for app-wide events.
    ///
    /// These observers use the target-selector pattern with `self` as the observer.
    /// Cleanup is handled in AppDelegate.deinit via `NotificationCenter.default.removeObserver(self)`,
    /// which removes all observers registered with this instance. This is safe because:
    /// 1. AppDelegate lives for the entire app lifecycle
    /// 2. The deinit handler provides explicit cleanup if the delegate is somehow deallocated early
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDashboard),
            name: .welcomeCompleted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restoreFocusToPreviousApp),
            name: .restoreFocusToPreviousApp,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRecordingStopped),
            name: .recordingStopped,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPressAndHoldSettingsChanged(_:)),
            name: .pressAndHoldSettingsChanged,
            object: nil
        )
    }

    @objc private func onPressAndHoldSettingsChanged(_ notification: Notification) {
        configureShortcutMonitors()
    }
}
