import Foundation
import AppKit
import SwiftUI
import SwiftData
import os.log

/// Manages the transcription history window lifecycle to prevent memory leaks
/// and ensure only one instance exists at a time
@MainActor
final class HistoryWindowManager: NSObject {
    static let shared = HistoryWindowManager()
    
    private weak var historyWindow: NSWindow?
    private var windowDelegate: HistoryWindowDelegate?
    private let isTestEnvironment: Bool
    
    private override init() {
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
        super.init()
    }
    
    /// Shows the history window, creating it if necessary or bringing existing one to front
    func showHistoryWindow() {
        // Skip actual window operations in test environment
        if isTestEnvironment {
            return
        }
        
        if let existingWindow = historyWindow, existingWindow.isVisible {
            // Window already exists and is visible, just bring it to front
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new window
        let historyView = TranscriptionHistoryView()
            .modelContainer(DataManager.shared.sharedModelContainer ?? createFallbackContainer())
        
        let hostingController = NSHostingController(rootView: historyView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure window to not interfere with app lifecycle
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        
        window.contentViewController = hostingController
        window.title = "Transcription History"
        window.setContentSize(NSSize(width: 800, height: 500))
        window.minSize = NSSize(width: 700, height: 400)
        window.center()
        
        // Ensure window doesn't cause app to quit when closed
        window.isReleasedWhenClosed = false
        
        // IMPORTANT: Set delegate before showing window
        windowDelegate = HistoryWindowDelegate(manager: self)
        window.delegate = windowDelegate
        
        // Store weak reference
        historyWindow = window
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        Logger.app.info("History window created and shown")
    }
    
    /// Called when the history window is closing
    func windowWillClose() {
        // Clean up references
        historyWindow = nil
        windowDelegate = nil
        Logger.app.info("History window closed and references cleaned up")
    }
    
    /// Creates a fallback container if DataManager isn't initialized
    private func createFallbackContainer() -> ModelContainer {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            Logger.app.error("Failed to create fallback ModelContainer: \(error)")
            // Return a memory-only container as last resort
            return try! ModelContainer(for: TranscriptionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}

/// Window delegate that handles the history window lifecycle
private class HistoryWindowDelegate: NSObject, NSWindowDelegate {
    private weak var manager: HistoryWindowManager?
    
    init(manager: HistoryWindowManager) {
        self.manager = manager
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        manager?.windowWillClose()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Always allow the window to close, but don't quit the app
        return true
    }
}