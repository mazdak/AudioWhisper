import Foundation

/// HTTP client for the Twilio REST API (2010-04-01).
/// Handles authentication, request building, and response parsing.
actor TwilioAPIClient {
    private let session: URLSession
    private let baseURL = "https://api.twilio.com/2010-04-01"

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Phone Numbers

    /// Fetch all phone numbers owned by this account.
    func fetchPhoneNumbers(credentials: TwilioCredentials) async throws -> [TwilioPhoneNumber] {
        let url = "\(baseURL)/Accounts/\(credentials.accountSID)/IncomingPhoneNumbers.json"
        let data = try await performRequest(url: url, credentials: credentials)
        let response = try decode(PhoneNumbersResponse.self, from: data)
        return response.incomingPhoneNumbers
    }

    // MARK: - Messages

    /// Fetch recent messages, optionally filtered by a specific phone number.
    func fetchMessages(
        credentials: TwilioCredentials,
        filterNumber: String? = nil,
        pageSize: Int = 200
    ) async throws -> [Message] {
        var urlString = "\(baseURL)/Accounts/\(credentials.accountSID)/Messages.json?PageSize=\(pageSize)"
        if let filterNumber {
            // Fetch both sent-to and received-from for this number
            let encoded = filterNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filterNumber
            // We'll need two requests for bidirectional filtering
            let toURL = urlString + "&To=\(encoded)"
            let fromURL = urlString + "&From=\(encoded)"

            async let toData = performRequest(url: toURL, credentials: credentials)
            async let fromData = performRequest(url: fromURL, credentials: credentials)

            let toResponse = try decode(MessagesResponse.self, from: try await toData)
            let fromResponse = try decode(MessagesResponse.self, from: try await fromData)

            var combined: [String: Message] = [:]
            for dto in toResponse.messages + fromResponse.messages {
                let msg = dto.toDomain()
                combined[msg.sid] = msg
            }
            return Array(combined.values).sorted {
                ($0.dateSent ?? $0.dateCreated) < ($1.dateSent ?? $1.dateCreated)
            }
        }

        let data = try await performRequest(url: urlString, credentials: credentials)
        let response = try decode(MessagesResponse.self, from: data)
        return response.messages.map { $0.toDomain() }
    }

    /// Send an SMS message.
    func sendMessage(
        credentials: TwilioCredentials,
        from: String,
        to: String,
        body: String
    ) async throws -> Message {
        let url = "\(baseURL)/Accounts/\(credentials.accountSID)/Messages.json"
        let params = [
            "From": from,
            "To": to,
            "Body": body
        ]
        let data = try await performRequest(url: url, method: "POST", formParams: params, credentials: credentials)
        let dto = try decode(TwilioMessageDTO.self, from: data)
        return dto.toDomain()
    }

    // MARK: - Calls

    /// Fetch recent call records.
    func fetchCalls(
        credentials: TwilioCredentials,
        pageSize: Int = 50
    ) async throws -> [PhoneCall] {
        let url = "\(baseURL)/Accounts/\(credentials.accountSID)/Calls.json?PageSize=\(pageSize)"
        let data = try await performRequest(url: url, credentials: credentials)
        let response = try decode(CallsResponse.self, from: data)
        return response.calls.map { $0.toDomain() }
    }

    /// Initiate an outbound call. Requires a TwiML URL or TwiML application.
    func makeCall(
        credentials: TwilioCredentials,
        from: String,
        to: String,
        twimlURL: String
    ) async throws -> PhoneCall {
        let url = "\(baseURL)/Accounts/\(credentials.accountSID)/Calls.json"
        let params = [
            "From": from,
            "To": to,
            "Url": twimlURL
        ]
        let data = try await performRequest(url: url, method: "POST", formParams: params, credentials: credentials)
        let dto = try decode(TwilioCallDTO.self, from: data)
        return dto.toDomain()
    }

    // MARK: - Account Verification

    /// Verify that the credentials are valid by fetching account info.
    func verifyCredentials(_ credentials: TwilioCredentials) async throws -> Bool {
        let url = "\(baseURL)/Accounts/\(credentials.accountSID).json"
        _ = try await performRequest(url: url, credentials: credentials)
        return true
    }

    // MARK: - Private Helpers

    private func performRequest(
        url: String,
        method: String = "GET",
        formParams: [String: String]? = nil,
        credentials: TwilioCredentials
    ) async throws -> Data {
        guard credentials.isValid else {
            throw NetworkError.invalidCredentials
        }

        guard let requestURL = URL(string: url) else {
            throw NetworkError.badRequest("Invalid URL: \(url)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        request.setValue(credentials.basicAuthHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let formParams {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let bodyString = formParams
                .map { key, value in
                    let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                    let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                    return "\(encodedKey)=\(encodedValue)"
                }
                .joined(separator: "&")
            request.httpBody = bodyString.data(using: .utf8)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw NetworkError.networkUnavailable
        } catch {
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "TwilioAPI", code: -1))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw NetworkError.invalidCredentials
        case 400:
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.badRequest(detail)
        case 404:
            throw NetworkError.notFound
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    private func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
