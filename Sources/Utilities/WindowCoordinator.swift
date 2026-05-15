import AppKit
import SwiftUI
import os.log

/// Centralizes window-presentation routing so individual views don't depend on
/// specific window-manager singletons. Wire one instance into the environment
/// at app startup; views call into it via `@EnvironmentObject`.
internal final class WindowCoordinator: ObservableObject {
    static let shared = WindowCoordinator()

    /// Show the Dashboard window, optionally with a hint about why we're opening
    /// it (e.g. "transcriptionError"). The reason is logged but does not change
    /// behavior today; future routing can dispatch on it.
    @MainActor
    func presentDashboard(reason: String? = nil) {
        if let reason {
            Logger.app.debug("WindowCoordinator.presentDashboard reason=\(reason, privacy: .public)")
        }
        DashboardWindowManager.shared.showDashboardWindow()
    }
}
