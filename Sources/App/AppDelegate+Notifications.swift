import AppKit

internal extension AppDelegate {
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
