import AppKit

// Lightweight mock of NSRunningApplication used by PasteManager tests
final class MockRunningApplication: NSRunningApplication {
    var mockIsTerminated: Bool = false
    var mockActivationCount: Int = 0

    override var isTerminated: Bool { mockIsTerminated }

    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        mockActivationCount += 1
        return true
    }
}

