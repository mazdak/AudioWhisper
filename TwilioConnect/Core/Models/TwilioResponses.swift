import Foundation

/// Generic paginated list response from Twilio REST API.
struct TwilioPageResponse<T: Codable>: Codable {
    let firstPageUri: String?
    let nextPageUri: String?
    let previousPageUri: String?
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case firstPageUri = "first_page_uri"
        case nextPageUri = "next_page_uri"
        case previousPageUri = "previous_page_uri"
        case page
        case pageSize = "page_size"
    }
}

/// Response wrapper for /Messages.json
struct MessagesResponse: Codable {
    let messages: [TwilioMessageDTO]
    let firstPageUri: String?
    let nextPageUri: String?
    let previousPageUri: String?
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case messages
        case firstPageUri = "first_page_uri"
        case nextPageUri = "next_page_uri"
        case previousPageUri = "previous_page_uri"
        case page
        case pageSize = "page_size"
    }
}

/// Response wrapper for /Calls.json
struct CallsResponse: Codable {
    let calls: [TwilioCallDTO]
    let firstPageUri: String?
    let nextPageUri: String?
    let previousPageUri: String?
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case calls
        case firstPageUri = "first_page_uri"
        case nextPageUri = "next_page_uri"
        case previousPageUri = "previous_page_uri"
        case page
        case pageSize = "page_size"
    }
}

/// Response wrapper for /IncomingPhoneNumbers.json
struct PhoneNumbersResponse: Codable {
    let incomingPhoneNumbers: [TwilioPhoneNumber]

    enum CodingKeys: String, CodingKey {
        case incomingPhoneNumbers = "incoming_phone_numbers"
    }
}

// MARK: - DTOs (data transfer objects matching Twilio JSON)

struct TwilioMessageDTO: Codable {
    let sid: String
    let from: String?
    let to: String
    let body: String
    let status: String
    let direction: String
    let dateSent: String?
    let dateCreated: String

    enum CodingKeys: String, CodingKey {
        case sid, from, to, body, status, direction
        case dateSent = "date_sent"
        case dateCreated = "date_created"
    }

    func toDomain() -> Message {
        let formatter = DateFormatter.twilioRFC2822
        return Message(
            sid: sid,
            from: from ?? "",
            to: to,
            body: body,
            status: MessageStatus(rawValue: status) ?? .unknown,
            direction: MessageDirection(rawValue: direction) ?? .unknown,
            dateSent: dateSent.flatMap { formatter.date(from: $0) },
            dateCreated: formatter.date(from: dateCreated) ?? Date()
        )
    }
}

struct TwilioCallDTO: Codable {
    let sid: String
    let from: String?
    let to: String
    let status: String
    let direction: String
    let duration: String?
    let startTime: String?
    let dateCreated: String

    enum CodingKeys: String, CodingKey {
        case sid, from, to, status, direction, duration
        case startTime = "start_time"
        case dateCreated = "date_created"
    }

    func toDomain() -> PhoneCall {
        let formatter = DateFormatter.twilioRFC2822
        return PhoneCall(
            sid: sid,
            from: from ?? "",
            to: to,
            status: CallStatus(rawValue: status) ?? .unknown,
            direction: CallDirection(rawValue: direction) ?? .unknown,
            duration: duration,
            startTime: startTime.flatMap { formatter.date(from: $0) },
            dateCreated: formatter.date(from: dateCreated) ?? Date()
        )
    }
}
