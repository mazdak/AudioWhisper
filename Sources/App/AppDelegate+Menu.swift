import AppKit
import os.log
import UniformTypeIdentifiers

internal extension AppDelegate {
    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.record, action: #selector(toggleRecordWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Transcribe Audio File...", action: #selector(transcribeAudioFile), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Dashboard...", action: #selector(showDashboard), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Help", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: LocalizedStrings.Menu.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        return menu
    }

    @MainActor @objc func showDashboard() {
        Logger.app.info("Dashboard menu item selected")
        DashboardWindowManager.shared.showDashboardWindow()
    }

    @MainActor @objc func showSettings() {
        Logger.app.info("Settings menu item selected")
        DashboardWindowManager.shared.showDashboardWindow(selectedNav: .preferences)
    }

    @objc func showHelp() {
        let shouldOpenSettings = WelcomeWindow.showWelcomeDialog()

        if shouldOpenSettings {
            DashboardWindowManager.shared.showDashboardWindow()
        }
    }

    @objc func transcribeAudioFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .mpeg4Audio,
            .mp3,
            .wav,
            .aiff,
            .init(filenameExtension: "m4a")!,
            .init(filenameExtension: "aac") ?? .mpeg4Audio,
            .init(filenameExtension: "flac") ?? .audio,
            .init(filenameExtension: "caf") ?? .audio
        ]
        panel.message = "Select an audio file to transcribe"
        panel.prompt = "Transcribe"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.processAudioFile(url)
        }
    }

    private func processAudioFile(_ url: URL) {
        if recordingWindow == nil {
            createRecordingWindow()
        }
        guard let window = recordingWindow else { return }

        if !window.isVisible {
            windowController.toggleRecordWindow(window)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: .transcribeAudioFile,
                object: url
            )
        }
    }

    @objc func screenConfigurationChanged() {
        AppSetupHelper.resetIconSizeCache()

        if let button = statusItem?.button {
            button.image = AppSetupHelper.createMenuBarIcon()
        }
    }
}
