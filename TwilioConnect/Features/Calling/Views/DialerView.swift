import SwiftUI

/// Phone dialer with number pad for making outbound calls.
struct DialerView: View {
    @ObservedObject var viewModel: CallViewModel
    @ObservedObject var callManager: CallManager
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private let dialPad: [(String, String)] = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"),
        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
        ("*", ""), ("0", "+"), ("#", "")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Number display
            Text(viewModel.dialerNumber.isEmpty ? "Enter Number" : viewModel.dialerNumber)
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.dialerNumber.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 32)
                .frame(height: 50)

            // Dial pad
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(dialPad, id: \.0) { digit, letters in
                    DialButton(digit: digit, letters: letters) {
                        viewModel.appendDigit(digit)
                    }
                }
            }
            .padding(.horizontal, 32)

            // Action buttons
            HStack(spacing: 48) {
                // Spacer for symmetry
                Color.clear.frame(width: 64, height: 64)

                // Call button
                Button {
                    Task { await makeCall() }
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(.green, in: Circle())
                }
                .disabled(viewModel.dialerNumber.isEmpty || callManager.isOnCall)

                // Delete button
                Button {
                    viewModel.deleteLastDigit()
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 64, height: 64)
                }
                .opacity(viewModel.dialerNumber.isEmpty ? 0 : 1)
            }

            Spacer()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func makeCall() async {
        let number = viewModel.dialerNumber.toE164
        do {
            try await callManager.startOutgoingCall(to: number)
            viewModel.clearDialer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Dial Button

private struct DialButton: View {
    let digit: String
    let letters: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(digit)
                    .font(.system(size: 28, weight: .light))
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .background(Color(.systemGray5), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DialerView(viewModel: CallViewModel(), callManager: CallManager.shared)
}
