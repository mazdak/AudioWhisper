import Foundation
@testable import AudioWhisper

class MockKeychainService: KeychainServiceProtocol {
    private var storage: [String: String] = [:]
    var shouldThrow = false
    var throwError: KeychainError = .itemNotFound
    
    func save(_ key: String, service: String, account: String) throws {
        if shouldThrow {
            throw throwError
        }
        let storageKey = "\(service):\(account)"
        storage[storageKey] = key
    }
    
    func get(service: String, account: String) throws -> String? {
        if shouldThrow {
            throw throwError
        }
        let storageKey = "\(service):\(account)"
        return storage[storageKey]
    }
    
    func delete(service: String, account: String) throws {
        if shouldThrow {
            throw throwError
        }
        let storageKey = "\(service):\(account)"
        storage.removeValue(forKey: storageKey)
    }
    
    // Backward compatibility methods
    func saveQuietly(_ key: String, service: String, account: String) {
        try? save(key, service: service, account: account)
    }
    
    func getQuietly(service: String, account: String) -> String? {
        return try? get(service: service, account: account)
    }
    
    func deleteQuietly(service: String, account: String) {
        try? delete(service: service, account: account)
    }
    
    // Test helpers
    func clear() {
        storage.removeAll()
    }
    
    func contains(service: String, account: String) -> Bool {
        let storageKey = "\(service):\(account)"
        return storage[storageKey] != nil
    }
}