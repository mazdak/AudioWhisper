import Foundation

/// A single SMS message from the Twilio Messages resource.
struct Message: Identifiable, Codable, Equatable {
    let sid: String
    let from: String
    let to: String
    let body: String
    let status: MessageStatus
    let direction: MessageDirection
    let dateSent: Date?
    let dateCreated: Date

    var id: String { sid }

    /// The "other party" phone number (not our Twilio number).
    func counterparty(myNumber: String) -> String {
        direction == .inbound ? from : to
    }
}

enum MessageStatus: String, Codable {
    case queued, sending, sent, delivered, undelivered, failed, receiving, received
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = MessageStatus(rawValue: value) ?? .unknown
    }
}

enum MessageDirection: String, Codable {
    case inbound = "inbound"
    case outbound = "outbound-api"
    case outboundCall = "outbound-call"
    case outboundReply = "outbound-reply"
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = MessageDirection(rawValue: value) ?? .unknown
    }

    var isOutbound: Bool {
        switch self {
        case .inbound: return false
        default: return true
        }
    }
}

/// A grouped conversation thread between the user's Twilio number and a contact.
struct Conversation: Identifiable {
    let phoneNumber: String
    var messages: [Message]

    var id: String { phoneNumber }

    var lastMessage: Message? {
        messages.sorted { ($0.dateSent ?? $0.dateCreated) > ($1.dateSent ?? $1.dateCreated) }.first
    }

    var lastMessageDate: Date {
        lastMessage?.dateSent ?? lastMessage?.dateCreated ?? .distantPast
    }

    var unreadCount: Int {
        messages.filter { $0.direction == .inbound && $0.status == .received }.count
    }
}
