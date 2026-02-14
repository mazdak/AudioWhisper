import Foundation
import Security

/// Manages secure storage of Twilio credentials in the iOS Keychain.
final class KeychainManager: Sendable {
    static let shared = KeychainManager()

    private let service = "com.twilioconnect.credentials"
    private let accountSIDKey = "twilio_account_sid"
    private let authTokenKey = "twilio_auth_token"
    private let phoneNumberKey = "twilio_phone_number"

    private init() {}

    // MARK: - Credentials

    func saveCredentials(_ credentials: TwilioCredentials) throws {
        try save(key: accountSIDKey, value: credentials.accountSID)
        try save(key: authTokenKey, value: credentials.authToken)
    }

    func loadCredentials() -> TwilioCredentials? {
        guard let sid = load(key: accountSIDKey),
              let token = load(key: authTokenKey) else {
            return nil
        }
        return TwilioCredentials(accountSID: sid, authToken: token)
    }

    func deleteCredentials() {
        delete(key: accountSIDKey)
        delete(key: authTokenKey)
    }

    // MARK: - Selected Phone Number

    func saveSelectedPhoneNumber(_ number: String) throws {
        try save(key: phoneNumberKey, value: number)
    }

    func loadSelectedPhoneNumber() -> String? {
        load(key: phoneNumberKey)
    }

    func deleteSelectedPhoneNumber() {
        delete(key: phoneNumberKey)
    }

    // MARK: - Generic Keychain Operations

    private func save(key: String, value: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        }
    }
}
