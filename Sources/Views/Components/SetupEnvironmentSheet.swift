import SwiftUI

internal struct SetupEnvironmentSheet: View {
    @Binding var isPresented: Bool
    @Binding var isRunning: Bool
    @Binding var logs: String
    let title: String
    let onStart: () -> Void
    
    private var isSuccess: Bool {
        !isRunning && title.lowercased().contains("ready")
    }
    
    private var isError: Bool {
        (!isRunning && title.lowercased().contains("failed")) || logs.lowercased().contains("error")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(isSuccess ? .title3 : .headline)
                    .foregroundStyle(isSuccess ? .green : .primary)
                Spacer()
                if isRunning { ProgressView().controlSize(.small) }
            }
            .padding(.bottom, 4)

            ScrollView {
                Text(logs.isEmpty ? "Starting…" : logs)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isError ? .red : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(width: 420, height: 180)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

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
