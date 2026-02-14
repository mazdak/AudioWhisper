import Foundation
import SwiftUI

/// Manages Twilio credential configuration and account verification.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var accountSID: String = ""
    @Published var authToken: String = ""
    @Published var selectedPhoneNumber: String = ""
    @Published var availablePhoneNumbers: [TwilioPhoneNumber] = []

    @Published var isVerifying = false
    @Published var isLoadingNumbers = false
    @Published var verificationStatus: VerificationStatus = .none
    @Published var errorMessage: String?

    enum VerificationStatus: Equatable {
        case none
        case verified
        case failed(String)
    }

    private let keychain = KeychainManager.shared
    private let apiClient = TwilioAPIClient()

    var hasCredentials: Bool {
        !accountSID.isEmpty && !authToken.isEmpty
    }

    var credentials: TwilioCredentials {
        TwilioCredentials(accountSID: accountSID, authToken: authToken)
    }

    init() {
        loadSavedCredentials()
    }

    func loadSavedCredentials() {
        if let saved = keychain.loadCredentials() {
            accountSID = saved.accountSID
            authToken = saved.authToken
        }
        if let number = keychain.loadSelectedPhoneNumber() {
            selectedPhoneNumber = number
        }
    }

    func saveCredentials() {
        do {
            try keychain.saveCredentials(credentials)
            if !selectedPhoneNumber.isEmpty {
                try keychain.saveSelectedPhoneNumber(selectedPhoneNumber)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyAndSave() async {
        guard credentials.isValid else {
            verificationStatus = .failed("Account SID must start with 'AC' and Auth Token cannot be empty.")
            return
        }

        isVerifying = true
        errorMessage = nil

        do {
            let valid = try await apiClient.verifyCredentials(credentials)
            if valid {
                verificationStatus = .verified
                saveCredentials()
                await fetchPhoneNumbers()
            }
        } catch {
            verificationStatus = .failed(error.localizedDescription)
        }

        isVerifying = false
    }

    func fetchPhoneNumbers() async {
        guard credentials.isValid else { return }

        isLoadingNumbers = true
        do {
            availablePhoneNumbers = try await apiClient.fetchPhoneNumbers(credentials: credentials)
            // Auto-select first number if none selected
            if selectedPhoneNumber.isEmpty, let first = availablePhoneNumbers.first {
                selectedPhoneNumber = first.phoneNumber
                try? keychain.saveSelectedPhoneNumber(first.phoneNumber)
            }
        } catch {
            errorMessage = "Failed to fetch phone numbers: \(error.localizedDescription)"
        }
        isLoadingNumbers = false
    }

    func selectPhoneNumber(_ number: String) {
        selectedPhoneNumber = number
        try? keychain.saveSelectedPhoneNumber(number)
    }

    func signOut() {
        keychain.deleteCredentials()
        keychain.deleteSelectedPhoneNumber()
        accountSID = ""
        authToken = ""
        selectedPhoneNumber = ""
        availablePhoneNumbers = []
        verificationStatus = .none
    }
}
