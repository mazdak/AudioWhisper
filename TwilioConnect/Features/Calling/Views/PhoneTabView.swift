import SwiftUI

/// Container view for the Phone tab, switching between dialer and call history.
struct PhoneTabView: View {
    @StateObject private var viewModel = CallViewModel()
    @ObservedObject var callManager: CallManager
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("Keypad").tag(0)
                    Text("Recents").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if selectedSegment == 0 {
                    DialerView(viewModel: viewModel, callManager: callManager)
                } else {
                    CallHistoryView(viewModel: viewModel)
                }
            }
            .navigationTitle("Phone")
            .fullScreenCover(isPresented: $callManager.isOnCall) {
                ActiveCallView(callManager: callManager)
            }
        }
    }
}

#Preview {
    PhoneTabView(callManager: CallManager.shared)
}
