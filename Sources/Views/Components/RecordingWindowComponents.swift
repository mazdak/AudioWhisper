import AppKit
import SwiftUI

internal class ChromelessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

internal struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        // Keep the recording window feeling like a light, translucent HUD that adapts to Light/Dark Mode.
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = LayoutMetrics.RecordingWindow.cornerRadius
        effectView.layer?.masksToBounds = true
        return effectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

internal class RecordingWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
