import AppKit
import SwiftUI

class WelcomeWindow {
    static func showWelcomeDialog() -> Bool {
        // Show the new SwiftUI welcome window
        let welcomeView = WelcomeView()
        let hostingController = NSHostingController(rootView: welcomeView)
        
        // Get the main screen dimensions for proper centering
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 650
        
        let window = NSWindow(
            contentRect: NSRect(
                x: (screenFrame.width - windowWidth) / 2,
                y: (screenFrame.height - windowHeight) / 2,
                width: windowWidth,
                height: windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "Welcome to AudioWhisper"
        window.isReleasedWhenClosed = false
        
        // Ensure proper focus and activation
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Force focus after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKey()
        }
        
        // Run the window modally
        let response = NSApplication.shared.runModal(for: window)
        window.close()
        
        return response == .OK
    }
}