import AppKit
import os.log

internal extension AppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI initialization in test environment
        let isTestEnvironment = NSClassFromString("XCTestCase") != nil
        if isTestEnvironment {
            Logger.app.info("Test environment detected - skipping UI initialization")
            return
        }

        do {
            try DataManager.shared.initialize()
            Logger.app.info("DataManager initialized successfully")
        } catch {
            Logger.app.error("Failed to initialize DataManager: \(error.localizedDescription)")
            // App continues with in-memory fallback
        }

        Task { await UsageMetricsStore.shared.bootstrapIfNeeded() }

        AppSetupHelper.setupApp()

        audioRecorder = AudioRecorder()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = AppSetupHelper.createMenuBarIcon()
            button.action = #selector(toggleRecordWindow)
            button.target = self
        }
        statusItem?.menu = makeStatusMenu()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.handleHotkey(source: .standardHotkey)
        }
        keyboardEventHandler = KeyboardEventHandler()
        configureShortcutMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        setupNotificationObservers()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if AppSetupHelper.checkFirstRun() {
                self.showWelcomeAndSettings()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app running in menu bar
    }

    func applicationWillTerminate(_ notification: Notification) {
        recordingAnimationTimer?.cancel()
        recordingAnimationTimer = nil

        recordingWindow = nil
        recordingWindowDelegate = nil

        AppSetupHelper.cleanupOldTemporaryFiles()
    }

    func hasAPIKey(service: String, account: String) -> Bool {
        KeychainService.shared.getQuietly(service: service, account: account) != nil
    }

    func showWelcomeAndSettings() {
        let shouldOpenSettings = WelcomeWindow.showWelcomeDialog()

        if shouldOpenSettings {
            DashboardWindowManager.shared.showDashboardWindow()
        }
    }
}
