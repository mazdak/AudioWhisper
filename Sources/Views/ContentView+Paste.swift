import SwiftUI
import AppKit
import os.log

private final class ObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _observer: NSObjectProtocol?

    var observer: NSObjectProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _observer
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _observer = newValue
        }
    }
}

// Note: ResumedFlag is defined in PasteManager.swift

internal extension ContentView {
    func performUserTriggeredPaste() {
        Logger.paste.debug("performUserTriggeredPaste called")
        guard let targetApp = findValidTargetApp() else {
            Logger.paste.warning("No valid target app found for paste")
            showSuccess = false
            hideRecordingWindow()
            return
        }

        Logger.paste.debug("Target app found: \(targetApp.localizedName ?? "unknown", privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hideRecordingWindow()
            self.activateTargetAppAndPaste(targetApp)
        }
    }
    
    func findValidTargetApp() -> NSRunningApplication? {
        Logger.paste.debug("findValidTargetApp: checking WindowController.storedTargetApp")
        var targetApp = WindowController.storedTargetApp
        if let app = targetApp {
            Logger.paste.debug("findValidTargetApp: storedTargetApp = \(app.localizedName ?? "unknown", privacy: .public)")
        } else {
            Logger.paste.debug("findValidTargetApp: storedTargetApp is nil")
        }

        if targetApp == nil {
            Logger.paste.debug("findValidTargetApp: checking targetAppForPaste")
            targetApp = targetAppForPaste
            if let app = targetApp {
                Logger.paste.debug("findValidTargetApp: targetAppForPaste = \(app.localizedName ?? "unknown", privacy: .public)")
            }
        }

        if let stored = targetApp, stored.isTerminated {
            Logger.paste.debug("findValidTargetApp: target app is terminated, clearing")
            targetApp = nil
        }

        if targetApp == nil {
            Logger.paste.debug("findValidTargetApp: falling back to findFallbackTargetApp")
            targetApp = findFallbackTargetApp()
            if let app = targetApp {
                Logger.paste.debug("findValidTargetApp: fallback found \(app.localizedName ?? "unknown", privacy: .public)")
            } else {
                Logger.paste.warning("findValidTargetApp: no fallback app found")
            }
        }

        return targetApp
    }
    
    func findFallbackTargetApp() -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        return runningApps.first { app in
            app.bundleIdentifier != Bundle.main.bundleIdentifier &&
            app.bundleIdentifier != "com.tinyspeck.slackmacgap" &&
            app.bundleIdentifier != "com.cron.electron" &&
            app.activationPolicy == .regular &&
            !app.isTerminated
        }
    }

    func hideRecordingWindow() {
        let recordWindow = NSApp.windows.first { window in
            window.title == WindowTitles.recording
        }
        if let window = recordWindow {
            fadeOutWindow(window)
        } else if let keyWindow = NSApplication.shared.keyWindow {
            fadeOutWindow(keyWindow)
        }
    }

    func fadeOutWindow(_ window: NSWindow, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1.0  // Reset for next show
            completion?()
        })
    }
    
    func activateTargetAppAndPaste(_ target: NSRunningApplication) {
        Logger.paste.debug("activateTargetAppAndPaste: activating \(target.localizedName ?? "unknown", privacy: .public)")
        Task { @MainActor in
            do {
                try await activateApplication(target)
                Logger.paste.debug("activateTargetAppAndPaste: app activated, calling pasteWithCompletionHandler")
                await pasteManager.pasteWithCompletionHandler()
                Logger.paste.debug("activateTargetAppAndPaste: paste completed")
                self.showSuccess = false
            } catch {
                Logger.paste.error("activateTargetAppAndPaste: failed with error: \(error.localizedDescription, privacy: .public)")
                self.showSuccess = false
            }
        }
    }

    func activateApplication(_ target: NSRunningApplication) async throws {
        let success = target.activate(options: [])
        
        if !success {
            if let bundleURL = target.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                
                return try await withCheckedThrowingContinuation { continuation in
                    NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } else {
                throw NSError(domain: "AudioWhisper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to activate target application"])
            }
        }
        
        await waitForApplicationActivation(target)
    }
    
    /// Waits for the target application to become active, with a timeout.
    ///
    /// Thread safety notes:
    /// - ResumedFlag ensures the continuation is resumed exactly once (tryResume returns true only on first call)
    /// - ObserverBox provides thread-safe storage for the observer reference
    /// - Observer removal is idempotent, so multiple removal attempts are harmless
    /// - Both timeout and notification paths clean up the observer before resuming
    func waitForApplicationActivation(_ target: NSRunningApplication) async {
        if target.isActive { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let observerBox = ObserverBox()
            let resumedFlag = ResumedFlag()

            // Helper to clean up observer and resume continuation exactly once
            func cleanupAndResume() {
                if let observer = observerBox.observer {
                    NotificationCenter.default.removeObserver(observer)
                    observerBox.observer = nil  // Clear to prevent redundant removal attempts
                }
                if resumedFlag.tryResume() {
                    continuation.resume()
                }
            }

            let timeoutTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                cleanupAndResume()
            }

            observerBox.observer = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   activatedApp.processIdentifier == target.processIdentifier {
                    timeoutTask.cancel()
                    cleanupAndResume()
                }
            }
        }
    }
}
