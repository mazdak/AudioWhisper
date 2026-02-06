import Foundation
import AppKit
import os.log

/// Manages window display and focus restoration for AudioWhisper
/// 
/// This class handles showing/hiding the recording window and restoring focus
/// to the previous application. All window operations now support optional
/// completion handlers for better coordination and testing.
internal class WindowController {
    private var previousApp: NSRunningApplication?
    private let isTestEnvironment: Bool
    
    // Thread-safe static property to share target app with ContentView
    private static let storedTargetAppQueue = DispatchQueue(label: "com.audiowhisper.storedTargetApp", attributes: .concurrent)
    private static var _storedTargetApp: NSRunningApplication?
    
    static var storedTargetApp: NSRunningApplication? {
        get {
            return storedTargetAppQueue.sync {
                return _storedTargetApp
            }
        }
        set {
            storedTargetAppQueue.sync(flags: .barrier) {
                _storedTargetApp = newValue
            }
        }
    }
    
    init() {
        isTestEnvironment = AppEnvironment.isRunningTests
    }
    
    func toggleRecordWindow(_ window: NSWindow? = nil, completion: (() -> Void)? = nil) {
        // Don't show recorder window during first-run welcome experience
        let hasCompletedWelcome = UserDefaults.standard.bool(forKey: "hasCompletedWelcome")
        if !hasCompletedWelcome {
            completion?()
            return
        }
        
        // In test environment, exit early
        if isTestEnvironment {
            completion?()
            return
        }
        
        // Use provided window or find the recording window by title
        let recordWindow = window ?? NSApp.windows.first { window in
            window.title == WindowTitles.recording
        }
        
        if let window = recordWindow {
            if window.isVisible {
                hideWindow(window, completion: completion)
            } else {
                showWindow(window, completion: completion)
            }
        } else {
            completion?()
        }
    }
    
    private func hideWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        fadeOutWindow(window) { [weak self] in
            self?.restoreFocusToPreviousApp(completion: completion)
        }
    }

    private func fadeOutWindow(_ window: NSWindow, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
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
    
    private func showWindow(_ window: NSWindow, completion: (() -> Void)? = nil) {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            completion?()
            return
        }

        // Remember the currently active app before showing our window
        storePreviousApp()

        // Configure window for overlay display without stealing focus or switching spaces
        window.canHide = false
        window.acceptsMouseMovedEvents = true
        window.isOpaque = false
        window.hasShadow = true

        // Set collection behavior to appear on all spaces including fullscreen
        // .canJoinAllSpaces - appear on any space
        // .fullScreenPrimary - appear on fullscreen spaces (primary display)
        // .fullScreenAuxiliary - appear on fullscreen spaces (secondary displays)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]

        // Use floating level - fullscreen visibility is handled by .fullScreenAuxiliary collectionBehavior,
        // not window level. .screenSaver is unnecessarily high and may interfere with input/focus.
        window.level = .floating

        // Show window without activating the app (prevents space switching)
        window.orderFrontRegardless()

        // Small delay then ensure proper focus
        performWindowOperation(after: 0.02) {
            if window.canBecomeKey {
                window.makeKey()
            }
            window.makeFirstResponder(window.contentView)
            completion?()
        }
    }
    
    /// Helper method to perform window operations with delays and completion handlers
    private func performWindowOperation(after delay: TimeInterval, operation: @escaping () -> Void) {
        Task { @MainActor in
            if delay > 0 {
                
                try? await Task.sleep(for: .seconds(delay))
            }
            operation()
        }
    }
    
    private func storePreviousApp() {
        let workspace = NSWorkspace.shared
        Logger.paste.debug("storePreviousApp called")
        if let frontmostApp = workspace.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmostApp
            WindowController.storedTargetApp = frontmostApp
            Logger.paste.debug("storePreviousApp: stored \(frontmostApp.localizedName ?? "unknown", privacy: .public)")

            // Also notify via NotificationCenter as backup
            NotificationCenter.default.post(
                name: .targetAppStored,
                object: frontmostApp
            )
        } else {
            Logger.paste.debug("storePreviousApp: no suitable frontmost app found")
        }
    }
    
    func restoreFocusToPreviousApp(completion: (() -> Void)? = nil) {
        guard let prevApp = previousApp else {
            completion?()
            return
        }
        
        // Small delay to ensure window is hidden first
        performWindowOperation(after: 0.1) { [weak self] in
            prevApp.activate(options: [])
            self?.previousApp = nil
            completion?()
        }
    }
    
    @MainActor func openSettings() {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            return
        }

        // Hide recording window if open to avoid overlap
        if let recordWindow = NSApp.windows.first(where: { $0.title == WindowTitles.recording }), recordWindow.isVisible {
            recordWindow.orderOut(nil)
        }

        DashboardWindowManager.shared.showDashboardWindow()
    }
}
