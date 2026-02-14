import Foundation

/// Represents a Twilio voice call record.
struct PhoneCall: Identifiable, Codable, Equatable {
    let sid: String
    let from: String
    let to: String
    let status: CallStatus
    let direction: CallDirection
    let duration: String?
    let startTime: Date?
    let dateCreated: Date

    var id: String { sid }

    var formattedDuration: String {
        guard let duration, let seconds = Int(duration) else { return "--" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    func counterparty(myNumber: String) -> String {
        direction == .inbound ? from : to
    }
}

enum CallStatus: String, Codable {
    case queued, ringing, inProgress = "in-progress"
    case completed, busy, noAnswer = "no-answer"
    case canceled, failed
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = CallStatus(rawValue: value) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .ringing: return "Ringing"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .busy: return "Busy"
        case .noAnswer: return "No Answer"
        case .canceled: return "Canceled"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }
}

enum CallDirection: String, Codable {
    case inbound = "inbound"
    case outbound = "outbound-api"
    case outboundDial = "outbound-dial"
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = CallDirection(rawValue: value) ?? .unknown
    }

    var isOutbound: Bool {
        self != .inbound
    }
}

/// Represents a Twilio phone number owned by the account.
struct TwilioPhoneNumber: Identifiable, Codable {
    let sid: String
    let phoneNumber: String
    let friendlyName: String

    var id: String { sid }

    enum CodingKeys: String, CodingKey {
        case sid
        case phoneNumber = "phone_number"
        case friendlyName = "friendly_name"
    }
}
