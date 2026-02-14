import SwiftUI

/// Modal sheet for composing a new SMS to a new phone number.
struct ComposeMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phoneNumber = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private let apiClient = TwilioAPIClient()
    private let keychain = KeychainManager.shared
    var onSent: (() -> Void)?

    var canSend: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("To:")
                            .foregroundStyle(.secondary)
                        TextField("+1 (555) 123-4567", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                }

                Section("Message") {
                    TextEditor(text: $messageBody)
                        .frame(minHeight: 100)
                }

                if let from = keychain.loadSelectedPhoneNumber() {
                    Section {
                        HStack {
                            Text("From:")
                                .foregroundStyle(.secondary)
                            Text(from.formattedPhoneNumber)
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Send")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSend)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func send() async {
        guard let credentials = keychain.loadCredentials(),
              let myNumber = keychain.loadSelectedPhoneNumber() else {
            errorMessage = "Twilio credentials not configured."
            return
        }

        isSending = true
        errorMessage = nil

        let to = phoneNumber.toE164

        do {
            _ = try await apiClient.sendMessage(
                credentials: credentials,
                from: myNumber,
                to: to,
                body: messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSent?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

#Preview {
    ComposeMessageView()
}
