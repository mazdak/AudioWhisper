import AppKit
import SwiftUI

class WindowManager: ObservableObject {
    weak var recordWindow: NSWindow?
    private var windowObserver: NSObjectProtocol?
    
    func setupRecordingWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.findAndConfigureWindow()
        }
    }
    
    private func findAndConfigureWindow() {
        // Find the main window with ContentView
        // Use NSApp.windows but guard against NSApp being nil (testing environment)
        guard let app = NSApp, !app.windows.isEmpty else {
            return
        }
        
        if let window = app.windows.first(where: { window in
            // Check for ContentView in either direct hosting view or as a hosted controller
            if window.contentView is NSHostingView<ContentView> {
                return true
            }
            if window.contentViewController is NSHostingController<ContentView> {
                return true
            }
            return false
        }) {
            configureWindow(window)
            setupWindowObserver(for: window)
            setInitialFocus(for: window)
            recordWindow = window
        } else {
            // Fallback: configure first available window
            configureFallbackWindow()
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        // Remove ALL window chrome - must be borderless only
        window.styleMask = [.borderless]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = .canJoinAllSpaces
        window.title = "AudioWhisper Recording"
        window.hasShadow = true
        window.isOpaque = false
        
        // Hide the title bar completely
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Force the window to update its appearance
        window.appearance = NSApp.appearance
        
        centerWindow(window)
        enableMouseTracking(for: window)
        preventFocusRing(for: window)
    }
    
    private func centerWindow(_ window: NSWindow) {
        window.center()
        
        // Reset to center of screen if position seems off
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        let windowFrame = window.frame
        let centeredOrigin = NSPoint(
            x: (screenFrame.width - windowFrame.width) / 2,
            y: (screenFrame.height - windowFrame.height) / 2 + 50 // Slightly above center
        )
        window.setFrameOrigin(centeredOrigin)
    }
    
    private func enableMouseTracking(for window: NSWindow) {
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
    }
    
    private func preventFocusRing(for window: NSWindow) {
        window.makeFirstResponder(nil)
    }
    
    private func setupWindowObserver(for window: NSWindow) {
        // Add click outside to dismiss
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { _ in
            // Dismiss recording window when it loses focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.orderOut(nil)
            }
        }
    }
    
    private func setInitialFocus(for window: NSWindow) {
        // Ensure initial window gets focus on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            window.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
            window.makeKey()
            window.makeFirstResponder(window.contentView)
        }
    }
    
    private func configureFallbackWindow() {
        // Guard against NSApp being nil (testing environment) and empty windows array
        guard let app = NSApp, !app.windows.isEmpty else {
            return
        }
        
        // Fallback: try to find any window and make it chromeless
        if let window = app.windows.first {
            window.styleMask = [.borderless, .fullSizeContentView]
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
            window.title = "AudioWhisper Recording"
            recordWindow = window
        }
    }
    
    func showRecordingWindow() {
        guard let window = recordWindow else { return }
        
        // Force window to current Space
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowFrame = window.frame
            let centeredOrigin = NSPoint(
                x: (screenFrame.width - windowFrame.width) / 2,
                y: (screenFrame.height - windowFrame.height) / 2 + 50
            )
            window.setFrameOrigin(centeredOrigin)
        }
        
        NSApp?.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeKey()
    }
    
    func hideRecordingWindow() {
        recordWindow?.orderOut(nil)
    }
    
    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}