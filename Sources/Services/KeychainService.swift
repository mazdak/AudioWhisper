import Foundation
import Security
import os.log

internal enum KeychainError: Error, LocalizedError {
    case invalidData
    case updateFailed(OSStatus)
    case addFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case unexpectedItemFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to encode keychain data"
        case .updateFailed(let status):
            return "Failed to update keychain item: \(status)"
        case .addFailed(let status):
            return "Failed to add keychain item: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete keychain item: \(status)"
        case .itemNotFound:
            return "Keychain item not found"
        case .unexpectedItemFormat:
            return "Unexpected keychain item format"
        }
    }
}

internal protocol KeychainServiceProtocol {
    func save(_ key: String, service: String, account: String) throws
    func get(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
    
    // Backward compatibility methods that don't throw
    func saveQuietly(_ key: String, service: String, account: String)
    func getQuietly(service: String, account: String) -> String?
    func deleteQuietly(service: String, account: String)
}

internal class KeychainService: KeychainServiceProtocol {
    static var shared: KeychainServiceProtocol = KeychainService()
    
    private init() {}
    
    func save(_ key: String, service: String, account: String) throws {
        if key.isEmpty {
            try delete(service: service, account: account)
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        if status == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if updateStatus != errSecSuccess {
                throw KeychainError.updateFailed(updateStatus)
            }
        } else {
            let attributes: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: keyData,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw KeychainError.addFailed(addStatus)
            }
        }
    }
    
    func get(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            guard let data = dataTypeRef as? Data else {
                throw KeychainError.unexpectedItemFormat
            }
            guard let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.itemNotFound
        }
    }
    
    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    // MARK: - Backward Compatibility Methods
    
    func saveQuietly(_ key: String, service: String, account: String) {
        do {
            try save(key, service: service, account: account)
        } catch {
            Logger.keychain.error("Keychain operation failed: \(error.localizedDescription)")
        }
    }
    
    func getQuietly(service: String, account: String) -> String? {
        do {
            return try get(service: service, account: account)
        } catch {
            Logger.keychain.error("Keychain operation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteQuietly(service: String, account: String) {
        do {
            try delete(service: service, account: account)
        } catch {
            Logger.keychain.error("Keychain operation failed: \(error.localizedDescription)")
        }
    }
}

// Mock implementation for testing
internal class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    private let queue = DispatchQueue(label: "MockKeychainService", attributes: .concurrent)
    
    func save(_ key: String, service: String, account: String) throws {
        let storageKey = "\(service)_\(account)"
        queue.sync(flags: .barrier) {
            if key.isEmpty {
                self.storage.removeValue(forKey: storageKey)
            } else {
                self.storage[storageKey] = key
            }
        }
    }
    
    func get(service: String, account: String) throws -> String? {
        let storageKey = "\(service)_\(account)"
        return queue.sync {
            return storage[storageKey]
        }
    }
    
    func delete(service: String, account: String) throws {
        let storageKey = "\(service)_\(account)"
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: storageKey)
        }
    }
    
    // MARK: - Backward Compatibility Methods
    
    func saveQuietly(_ key: String, service: String, account: String) {
        do {
            try save(key, service: service, account: account)
        } catch {
            Logger.keychain.error("Mock keychain operation failed: \(error.localizedDescription)")
        }
    }
    
    func getQuietly(service: String, account: String) -> String? {
        do {
            return try get(service: service, account: account)
        } catch {
            Logger.keychain.error("Mock keychain operation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteQuietly(service: String, account: String) {
        do {
            try delete(service: service, account: account)
        } catch {
            Logger.keychain.error("Mock keychain operation failed: \(error.localizedDescription)")
        }
    }
}