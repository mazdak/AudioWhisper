import Foundation
import SwiftUI
import Combine

/// Manages the list of SMS conversations, grouped by phone number.
@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = TwilioAPIClient()
    private let keychain = KeychainManager.shared
    private var refreshTimer: Timer?

    var credentials: TwilioCredentials? {
        keychain.loadCredentials()
    }

    var myPhoneNumber: String? {
        keychain.loadSelectedPhoneNumber()
    }

    var hasCredentials: Bool {
        credentials?.isValid == true
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
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
        guard let credentials, credentials.isValid else {
            errorMessage = "Please configure your Twilio credentials in Settings."
            return
        }

        if showLoading { isLoading = true }
        errorMessage = nil

        do {
            let messages = try await apiClient.fetchMessages(credentials: credentials)
            groupIntoConversations(messages)
        } catch {
            if showLoading {
                errorMessage = error.localizedDescription
            }
        }

        if showLoading { isLoading = false }
    }

    private func groupIntoConversations(_ messages: [Message]) {
        guard let myNumber = myPhoneNumber else { return }

        var grouped: [String: [Message]] = [:]
        for message in messages {
            let counterparty = message.counterparty(myNumber: myNumber)
            grouped[counterparty, default: []].append(message)
        }

        conversations = grouped.map { number, msgs in
            Conversation(
                phoneNumber: number,
                messages: msgs.sorted {
                    ($0.dateSent ?? $0.dateCreated) < ($1.dateSent ?? $1.dateCreated)
                }
            )
        }
        .sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
}
