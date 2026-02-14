import Foundation
import SwiftUI

/// Manages a single SMS conversation thread: loading messages and sending new ones.
@MainActor
final class ConversationDetailViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isSending = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    let contactNumber: String

    private let apiClient = TwilioAPIClient()
    private let keychain = KeychainManager.shared
    private var refreshTimer: Timer?

    var credentials: TwilioCredentials? {
        keychain.loadCredentials()
    }

    var myPhoneNumber: String? {
        keychain.loadSelectedPhoneNumber()
    }

    var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    init(contactNumber: String, initialMessages: [Message] = []) {
        self.contactNumber = contactNumber
        self.messages = initialMessages.sorted {
            ($0.dateSent ?? $0.dateCreated) < ($1.dateSent ?? $1.dateCreated)
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchMessages(showLoading: false)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchMessages(showLoading: Bool = true) async {
        guard let credentials, credentials.isValid else { return }

        if showLoading { isLoading = true }

        do {
            let fetched = try await apiClient.fetchMessages(
                credentials: credentials,
                filterNumber: contactNumber
            )
            messages = fetched.sorted {
                ($0.dateSent ?? $0.dateCreated) < ($1.dateSent ?? $1.dateCreated)
            }
        } catch {
            if showLoading {
                errorMessage = error.localizedDescription
            }
        }

        if showLoading { isLoading = false }
    }

    func sendMessage() async {
        guard canSend,
              let credentials,
              let myNumber = myPhoneNumber else { return }

        let body = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isSending = true
        errorMessage = nil

        do {
            let sent = try await apiClient.sendMessage(
                credentials: credentials,
                from: myNumber,
                to: contactNumber,
                body: body
            )
            messages.append(sent)
        } catch {
            errorMessage = error.localizedDescription
            messageText = body // Restore the message so user can retry
        }

        isSending = false
    }
}
