import SwiftUI

/// Main entry point for the TwilioConnect iOS app.
@main
struct TwilioConnectApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var callManager = CallManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(
                settingsViewModel: settingsViewModel,
                callManager: callManager
            )
        }
    }
}
