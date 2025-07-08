import Foundation
import Security

class MockKeychain {
    private var storage: [String: String] = [:]
    private var shouldFailOperations = false
    
    func setItem(_ value: String, forKey key: String) -> OSStatus {
        if shouldFailOperations {
            return errSecItemNotFound
        }
        storage[key] = value
        return errSecSuccess
    }
    
    func getItem(forKey key: String) -> (String?, OSStatus) {
        if shouldFailOperations {
            return (nil, errSecItemNotFound)
        }
        return (storage[key], errSecSuccess)
    }
    
    func deleteItem(forKey key: String) -> OSStatus {
        if shouldFailOperations {
            return errSecItemNotFound
        }
        storage.removeValue(forKey: key)
        return errSecSuccess
    }
    
    func setShouldFailOperations(_ shouldFail: Bool) {
        shouldFailOperations = shouldFail
    }
    
    func clear() {
        storage.removeAll()
    }
}