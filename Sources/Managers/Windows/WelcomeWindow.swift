import AppKit
import SwiftUI

internal class WelcomeWindow {
    // Tracks whether a dialog is already showing so we don't open two at once.
    private static var isShowing = false

    /// Shows the welcome dialog as a non-modal window and waits asynchronously for the user to
    /// complete or cancel the flow. Returns `true` if the user completed setup, `false` if they
    /// closed the window without finishing.
    ///
    /// Using a regular (non-modal) window is critical: `NSApplication.runModal` blocks the main
    /// thread in `NSModalPanelRunLoopMode`, which prevents `DispatchQueue.main` callbacks
    /// (including Swift Concurrency's `@MainActor` executor) from firing. That would freeze any
    /// `async`/`await` work started from within the welcome view.
    @MainActor
    static func showWelcomeDialog() async -> Bool {
        guard !isShowing else { return false }
        isShowing = true
        defer { isShowing = false }

        return await withCheckedContinuation { continuation in
            let state = WelcomeCompletionState(continuation: continuation)

            let welcomeView = WelcomeView { completed in
                state.complete(result: completed)
            }
            let hostingController = NSHostingController(rootView: welcomeView)

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

            let delegate = WelcomeWindowDelegate(state: state)
            window.delegate = delegate
            state.delegate = delegate
            state.window = window

            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Completion state

/// Reference type shared between WelcomeWindow, WelcomeView's completion callback, and the
/// window delegate. Guarantees the continuation is resumed exactly once.
private final class WelcomeCompletionState {
    private var resumed = false
    private var continuation: CheckedContinuation<Bool, Never>
    weak var window: NSWindow?
    var delegate: WelcomeWindowDelegate?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func complete(result: Bool) {
        guard !resumed else { return }
        resumed = true
        window?.close()
        window = nil
        delegate = nil
        continuation.resume(returning: result)
    }
}

// MARK: - Window delegate

private class WelcomeWindowDelegate: NSObject, NSWindowDelegate {
    private let state: WelcomeCompletionState

    init(state: WelcomeCompletionState) {
        self.state = state
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        state.complete(result: false)
        return false  // state.complete already closes the window
    }
}
