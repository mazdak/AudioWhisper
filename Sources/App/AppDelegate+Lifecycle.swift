import AppKit
import os.log

internal extension AppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register UserDefaults defaults - these are used when keys haven't been explicitly set
        AppDefaults.registerDefaults()

        // Skip UI initialization in test environment
        if AppEnvironment.isRunningTests {
            Logger.app.info("Test environment detected - skipping UI initialization")
            return
        }

        // Clear any corrupted window state restoration data (one-time migration)
        if !AppDefaults.hasCleanedWindowState {
            if let bundleId = Bundle.main.bundleIdentifier {
                let savedStatePath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("Saved Application State")
                    .appendingPathComponent("\(bundleId).savedState")
                if let path = savedStatePath, FileManager.default.fileExists(atPath: path.path) {
                    try? FileManager.default.removeItem(at: path)
                    Logger.app.info("Cleaned up corrupted window state restoration data")
                }
            }
            AppDefaults.hasCleanedWindowState = true
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

        audioRecorder = AudioEngineRecorder()

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

        // Proactively request microphone permission at first launch
        if PermissionManager.shared.microphonePermissionState.needsRequest {
            PermissionManager.shared.proceedWithPermissionRequest()
        }

        // Validate local model is ready before allowing use.
        // Preserves the legacy default-to-local behavior (no key set = treat as local)
        // which is also what `AppSetupHelper.checkFirstRun()` later writes.
        let providerRaw = AppDefaults.defaults.string(forKey: AppDefaults.Key.transcriptionProvider.rawValue) ?? TranscriptionProvider.local.rawValue
        if providerRaw == TranscriptionProvider.local.rawValue {
            let model = AppDefaults.selectedWhisperModel
            if !WhisperKitStorage.isModelDownloaded(model) {
                // Model not downloaded - show dashboard for download
                DashboardWindowManager.shared.showDashboardWindow()
                return
            }
        }

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
        Task { await MLDaemonManager.shared.shutdown() }
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
