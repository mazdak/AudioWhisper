import SwiftUI

/// Shows recent call history fetched from the Twilio API.
struct CallHistoryView: View {
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        Group {
            if !viewModel.hasCredentials {
                credentialsPrompt
            } else if viewModel.isLoading && viewModel.callHistory.isEmpty {
                ProgressView("Loading call history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.callHistory.isEmpty {
                emptyState
            } else {
                callList
            }
        }
        .task {
            await viewModel.fetchCallHistory()
        }
        .refreshable {
            await viewModel.fetchCallHistory()
        }
    }

    private var callList: some View {
        List(viewModel.callHistory) { call in
            CallHistoryRow(call: call, myNumber: viewModel.myPhoneNumber ?? "")
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Call History",
            systemImage: "phone",
            description: Text("Your call history will appear here.")
        )
    }

    private var credentialsPrompt: some View {
        ContentUnavailableView(
            "Setup Required",
            systemImage: "gear",
            description: Text("Configure your Twilio credentials in Settings to view call history.")
        )
    }
}

// MARK: - Call History Row

private struct CallHistoryRow: View {
    let call: PhoneCall
    let myNumber: String

    var body: some View {
        HStack(spacing: 12) {
            callDirectionIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(call.counterparty(myNumber: myNumber).formattedPhoneNumber)
                    .font(.body)

                HStack(spacing: 4) {
                    Text(call.status.displayName)
                        .font(.caption)
                        .foregroundStyle(statusColor)

                    if let duration = call.duration, !duration.isEmpty, duration != "0" {
                        Text("- \(call.formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text(call.dateCreated.conversationTimestamp)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var callDirectionIcon: some View {
        Group {
            switch call.direction {
            case .inbound:
                Image(systemName: "phone.arrow.down.left")
                    .foregroundStyle(call.status == .completed ? .green : .red)
            default:
                Image(systemName: "phone.arrow.up.right")
                    .foregroundStyle(.blue)
            }
        }
        .font(.title3)
        .frame(width: 36)
    }

    private var statusColor: Color {
        switch call.status {
        case .completed: return .green
        case .failed, .busy, .noAnswer: return .red
        case .canceled: return .orange
        default: return .secondary
        }
    }
}

#Preview {
    CallHistoryView(viewModel: CallViewModel())
}
