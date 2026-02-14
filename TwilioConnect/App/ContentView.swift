import SwiftUI

/// Root view with tab-based navigation across Messages, Phone, and Settings.
struct ContentView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var callManager: CallManager
    @State private var selectedTab: Tab = .messages

    enum Tab: Hashable {
        case messages
        case phone
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationsListView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(Tab.messages)

            PhoneTabView(callManager: callManager)
                .tabItem {
                    Label("Phone", systemImage: "phone.fill")
                }
                .tag(Tab.phone)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .onAppear {
            // Navigate to settings on first launch if no credentials
            if !settingsViewModel.hasCredentials {
                selectedTab = .settings
            }
        }
    }
}

#Preview {
    ContentView(
        settingsViewModel: SettingsViewModel(),
        callManager: CallManager.shared
    )
}
