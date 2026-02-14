import SwiftUI

/// Shows all SMS conversation threads grouped by contact number.
struct ConversationsListView: View {
    @StateObject private var viewModel = ConversationsViewModel()
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasCredentials {
                    credentialsPrompt
                } else if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(!viewModel.hasCredentials)
                }
            }
            .sheet(isPresented: $showCompose) {
                ComposeMessageView {
                    Task { await viewModel.fetchMessages() }
                }
            }
            .refreshable {
                await viewModel.fetchMessages()
            }
            .task {
                await viewModel.fetchMessages()
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var conversationsList: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink {
                ConversationView(
                    contactNumber: conversation.phoneNumber,
                    initialMessages: conversation.messages
                )
            } label: {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Messages",
            systemImage: "message",
            description: Text("Your SMS messages will appear here. Tap the compose button to send a new message.")
        )
    }

    private var credentialsPrompt: some View {
        ContentUnavailableView(
            "Setup Required",
            systemImage: "gear",
            description: Text("Configure your Twilio credentials in Settings to start messaging.")
        )
    }
}

// MARK: - Conversation Row

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(phoneNumber: conversation.phoneNumber)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.phoneNumber.formattedPhoneNumber)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Text(conversation.lastMessageDate.conversationTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastMessage = conversation.lastMessage {
                    HStack {
                        if lastMessage.direction.isOutbound {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(lastMessage.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationsListView()
}
