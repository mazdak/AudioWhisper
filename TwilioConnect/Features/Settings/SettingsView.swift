import SwiftUI

/// Settings screen for configuring Twilio account credentials and selecting a phone number.
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showAuthToken = false

    var body: some View {
        NavigationStack {
            Form {
                credentialsSection
                phoneNumberSection
                accountSection
            }
            .navigationTitle("Settings")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var credentialsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account SID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", text: $viewModel.accountSID)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Auth Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showAuthToken {
                            TextField("Auth Token", text: $viewModel.authToken)
                        } else {
                            SecureField("Auth Token", text: $viewModel.authToken)
                        }
                    }
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))

                    Button {
                        showAuthToken.toggle()
                    } label: {
                        Image(systemName: showAuthToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            Button {
                Task { await viewModel.verifyAndSave() }
            } label: {
                HStack {
                    if viewModel.isVerifying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isVerifying ? "Verifying..." : "Verify & Save")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isVerifying || !viewModel.hasCredentials)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            verificationStatusView
        } header: {
            Text("Twilio Credentials")
        } footer: {
            Text("Find your Account SID and Auth Token in the [Twilio Console](https://console.twilio.com).")
        }
    }

    @ViewBuilder
    private var verificationStatusView: some View {
        switch viewModel.verificationStatus {
        case .none:
            EmptyView()
        case .verified:
            Label("Credentials verified", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    @ViewBuilder
    private var phoneNumberSection: some View {
        if !viewModel.availablePhoneNumbers.isEmpty {
            Section("Twilio Phone Number") {
                ForEach(viewModel.availablePhoneNumbers) { number in
                    Button {
                        viewModel.selectPhoneNumber(number.phoneNumber)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(number.phoneNumber.formattedPhoneNumber)
                                    .foregroundStyle(.primary)
                                if !number.friendlyName.isEmpty && number.friendlyName != number.phoneNumber {
                                    Text(number.friendlyName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if viewModel.selectedPhoneNumber == number.phoneNumber {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        } else if viewModel.isLoadingNumbers {
            Section("Twilio Phone Number") {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading phone numbers...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if viewModel.verificationStatus == .verified {
            Section {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel())
}
