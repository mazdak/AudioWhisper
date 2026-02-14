import Foundation
import SwiftUI

/// Manages call history and dialer state.
@MainActor
final class CallViewModel: ObservableObject {
    @Published var callHistory: [PhoneCall] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dialerNumber = ""

    private let apiClient = TwilioAPIClient()
    private let keychain = KeychainManager.shared

    var credentials: TwilioCredentials? {
        keychain.loadCredentials()
    }

    var myPhoneNumber: String? {
        keychain.loadSelectedPhoneNumber()
    }

    var hasCredentials: Bool {
        credentials?.isValid == true
    }

    func fetchCallHistory() async {
        guard let credentials, credentials.isValid else {
            errorMessage = "Please configure your Twilio credentials in Settings."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            callHistory = try await apiClient.fetchCalls(credentials: credentials)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func appendDigit(_ digit: String) {
        dialerNumber.append(digit)
    }

    func deleteLastDigit() {
        guard !dialerNumber.isEmpty else { return }
        dialerNumber.removeLast()
    }

    func clearDialer() {
        dialerNumber = ""
    }
}
