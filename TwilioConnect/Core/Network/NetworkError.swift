import Foundation

/// Errors that can occur when communicating with the Twilio REST API.
enum NetworkError: LocalizedError {
    case invalidCredentials
    case missingCredentials
    case badRequest(String)
    case notFound
    case serverError(Int)
    case decodingFailed(Error)
    case networkUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Account SID or Auth Token. Please check your credentials in Settings."
        case .missingCredentials:
            return "Twilio credentials not configured. Go to Settings to add your Account SID and Auth Token."
        case .badRequest(let detail):
            return "Bad request: \(detail)"
        case .notFound:
            return "Resource not found."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingFailed(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network connection unavailable. Please check your internet connection."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
