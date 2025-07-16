import SwiftUI

struct SetupEnvironmentSheet: View {
    @Binding var isPresented: Bool
    @Binding var isRunning: Bool
    @Binding var logs: String
    let title: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                let isSuccess = !isRunning && title.lowercased().contains("ready")
                Text(title)
                    .font(isSuccess ? .title3 : .headline)
                    .foregroundColor(isSuccess ? .green : .primary)
                Spacer()
                if isRunning { ProgressView().controlSize(.small) }
            }
            .padding(.bottom, 4)

            ScrollView {
                Text(logs.isEmpty ? "Starting…" : logs)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(width: 420, height: 180)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            HStack {
                Spacer()
                Button(isRunning ? "Working…" : "Close") {
                    isPresented = false
                }
                .disabled(isRunning)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onAppear { onStart() }
    }
}
