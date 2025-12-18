import SwiftUI
import AppKit

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

internal extension ContentView {
    func performUserTriggeredPaste() {
        guard let targetApp = findValidTargetApp() else {
            showSuccess = false
            hideRecordingWindow()
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hideRecordingWindow()
            self.activateTargetAppAndPaste(targetApp)
        }
    }
    
    func findValidTargetApp() -> NSRunningApplication? {
        var targetApp = WindowController.storedTargetApp
        if targetApp == nil {
            targetApp = targetAppForPaste
        }
        
        if let stored = targetApp, stored.isTerminated {
            targetApp = nil
        }
        
        if targetApp == nil {
            targetApp = findFallbackTargetApp()
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
            window.title == "AudioWhisper Recording"
        }
        if let window = recordWindow {
            window.orderOut(nil)
        } else {
            NSApplication.shared.keyWindow?.orderOut(nil)
        }
    }
    
    func activateTargetAppAndPaste(_ target: NSRunningApplication) {
        Task { @MainActor in
            do {
                try await activateApplication(target)
                await pasteManager.pasteWithCompletionHandler()
                self.showSuccess = false
            } catch {
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
    
    func waitForApplicationActivation(_ target: NSRunningApplication) async {
        if target.isActive { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let observerBox = ObserverBox()
            
            let timeoutTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                if let observer = observerBox.observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume()
            }
            
            observerBox.observer = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                if let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   activatedApp.processIdentifier == target.processIdentifier {
                    timeoutTask.cancel()
                    if let observer = observerBox.observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    continuation.resume()
                }
            }
        }
    }
}
