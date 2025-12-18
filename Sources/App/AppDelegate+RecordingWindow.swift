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
            Logger.app.error("Cannot create recording window: AudioRecorder not initialized")
            return
        }

        let windowSize = LayoutMetrics.RecordingWindow.size
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.title = "AudioWhisper Recording"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isOpaque = false

        let contentView = ContentView(audioRecorder: recorder)
            .modelContainer(DataManager.shared.sharedModelContainer ?? createFallbackModelContainer())

        window.contentView = NSHostingView(rootView: contentView)
        window.center()

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

    private func createFallbackModelContainer() -> ModelContainer {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }

    @objc func restoreFocusToPreviousApp() {
        windowController.restoreFocusToPreviousApp()
    }
}
