import Foundation

/// Twilio account credentials required for API authentication.
struct TwilioCredentials: Codable, Equatable {
    let accountSID: String
    let authToken: String

    var isValid: Bool {
        !accountSID.trimmingCharacters(in: .whitespaces).isEmpty &&
        !authToken.trimmingCharacters(in: .whitespaces).isEmpty &&
        accountSID.hasPrefix("AC")
    }

    /// Base64-encoded credentials for HTTP Basic Auth.
    var basicAuthHeader: String {
        let raw = "\(accountSID):\(authToken)"
        return "Basic \(Data(raw.utf8).base64EncodedString())"
    }
}
