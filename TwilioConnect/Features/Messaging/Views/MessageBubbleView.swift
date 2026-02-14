import SwiftUI

/// A single message bubble in a conversation, aligned left (inbound) or right (outbound).
struct MessageBubbleView: View {
    let message: Message
    let isOutbound: Bool

    @State private var showTimestamp = false

    var body: some View {
        HStack {
            if isOutbound { Spacer(minLength: 60) }

            VStack(alignment: isOutbound ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: bubbleShape)
                    .foregroundStyle(isOutbound ? .white : .primary)

                if showTimestamp {
                    HStack(spacing: 4) {
                        Text((message.dateSent ?? message.dateCreated).messageDetailTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if isOutbound {
                            statusIcon
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTimestamp.toggle()
                }
            }

            if !isOutbound { Spacer(minLength: 60) }
        }
    }

    private var bubbleColor: Color {
        isOutbound ? .blue : Color(.systemGray5)
    }

    private var bubbleShape: some Shape {
        RoundedRectangle(cornerRadius: 18)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .delivered:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .sent, .queued, .sending:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed, .undelivered:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        default:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: Message(
                sid: "1", from: "+14155551234", to: "+14155555678",
                body: "Hey, how are you?", status: .received,
                direction: .inbound, dateSent: Date(), dateCreated: Date()
            ),
            isOutbound: false
        )
        MessageBubbleView(
            message: Message(
                sid: "2", from: "+14155555678", to: "+14155551234",
                body: "I'm doing great, thanks for asking! What about you?",
                status: .delivered, direction: .outbound,
                dateSent: Date(), dateCreated: Date()
            ),
            isOutbound: true
        )
    }
    .padding()
}
