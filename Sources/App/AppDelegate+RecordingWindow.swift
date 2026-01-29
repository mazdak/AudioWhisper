import AppKit
import os.log
import SwiftData
import SwiftUI

internal extension AppDelegate {
    @objc func toggleRecordWindow() {
        if recordingWindow == nil {
            createRecordingWindow()
        }

        windowController.toggleRecordWindow(recordingWindow)
    }

    func showRecordingWindowForProcessing(completion: (() -> Void)? = nil) {
        // Ensure we always have a fresh recording window
        if recordingWindow == nil {
            createRecordingWindow()
        }

        guard let window = recordingWindow else {
            completion?()
            return
        }

        if window.isVisible {
            completion?()
        } else {
            windowController.toggleRecordWindow(window) {
                completion?()
            }
        }
    }

    func createRecordingWindow() {
        guard let recorder = audioRecorder else {
            // Only log in non-test environment to reduce console noise
            if !AppEnvironment.isRunningTests {
                Logger.app.error("Cannot create recording window: AudioRecorder not initialized")
            }
            return
        }

        let windowSize = LayoutMetrics.RecordingWindow.size
        // Use ChromelessWindow to allow borderless window to become key
        let window = ChromelessWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.title = WindowTitles.recording
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        // Use floating level - fullscreen visibility is handled by .fullScreenAuxiliary collectionBehavior,
        // not window level. .screenSaver is unnecessarily high and may interfere with input/focus.
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isOpaque = false

        guard let container = DataManager.shared.sharedModelContainer ?? createFallbackModelContainer() else {
            Logger.app.error("Cannot create recording window: Failed to create ModelContainer")
            return
        }

        let contentView = ContentView(audioRecorder: recorder)
            .modelContainer(container)

        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isRestorable = false

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        recordingWindowDelegate = RecordingWindowDelegate { [weak self] in
            self?.onRecordingWindowClosed()
        }
        window.delegate = recordingWindowDelegate

        recordingWindow = window
    }

    private func onRecordingWindowClosed() {
        recordingWindow = nil
        recordingWindowDelegate = nil
        Logger.app.info("Recording window closed and references cleaned up")
    }

    private func createFallbackModelContainer() -> ModelContainer? {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.app.critical("Failed to create fallback ModelContainer: \(error)")
            return nil
        }
    }

    @objc func restoreFocusToPreviousApp() {
        windowController.restoreFocusToPreviousApp()
    }
}
