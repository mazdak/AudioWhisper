import Foundation

/// A lightweight dependency injection container for managing service instances.
///
/// This container provides a centralized way to access shared services while maintaining
/// testability. Services can be registered with protocols to allow mock implementations
/// in tests.
///
/// ## Usage
///
/// ```swift
/// // Access a service
/// let modelManager = DependencyContainer.shared.modelManager
///
/// // In tests, override with mocks
/// DependencyContainer.shared.register(modelManager: MockModelManager())
/// ```
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Service Storage

    private var _modelManager: ModelManager?
    private var _mlxModelManager: MLXModelManager?
    private var _keychainService: KeychainServiceProtocol?
    private var _dataManager: DataManager?
    private var _usageMetricsStore: UsageMetricsStore?
    private var _permissionManager: PermissionManager?
    private var _pasteManager: PasteManager?

    // MARK: - Service Accessors

    /// Access to the WhisperKit model manager
    var modelManager: ModelManager {
        _modelManager ?? ModelManager.shared
    }

    /// Access to the MLX model manager for semantic correction
    var mlxModelManager: MLXModelManager {
        _mlxModelManager ?? MLXModelManager.shared
    }

    /// Access to keychain services for secure storage
    var keychainService: KeychainServiceProtocol {
        _keychainService ?? KeychainService.shared
    }

    /// Access to the data manager for transcription history
    var dataManager: DataManager {
        _dataManager ?? DataManager.shared
    }

    /// Access to usage metrics tracking
    var usageMetricsStore: UsageMetricsStore {
        _usageMetricsStore ?? UsageMetricsStore.shared
    }

    /// Access to permission management
    var permissionManager: PermissionManager {
        _permissionManager ?? PermissionManager.shared
    }

    /// Access to paste functionality
    var pasteManager: PasteManager {
        _pasteManager ?? PasteManager()
    }

    // MARK: - Registration Methods

    /// Register a custom model manager (useful for testing)
    func register(modelManager: ModelManager) {
        _modelManager = modelManager
    }

    /// Register a custom MLX model manager (useful for testing)
    func register(mlxModelManager: MLXModelManager) {
        _mlxModelManager = mlxModelManager
    }

    /// Register a custom keychain service (useful for testing)
    func register(keychainService: KeychainServiceProtocol) {
        _keychainService = keychainService
    }

    /// Register a custom data manager (useful for testing)
    func register(dataManager: DataManager) {
        _dataManager = dataManager
    }

    /// Register a custom usage metrics store (useful for testing)
    func register(usageMetricsStore: UsageMetricsStore) {
        _usageMetricsStore = usageMetricsStore
    }

    /// Register a custom permission manager (useful for testing)
    func register(permissionManager: PermissionManager) {
        _permissionManager = permissionManager
    }

    /// Register a custom paste manager (useful for testing)
    func register(pasteManager: PasteManager) {
        _pasteManager = pasteManager
    }

    // MARK: - Reset

    /// Reset all registered services to defaults (for test cleanup)
    func reset() {
        _modelManager = nil
        _mlxModelManager = nil
        _keychainService = nil
        _dataManager = nil
        _usageMetricsStore = nil
        _permissionManager = nil
        _pasteManager = nil
    }
}

// MARK: - Property Wrapper for Dependency Injection

/// A property wrapper that provides convenient access to dependencies from the container.
///
/// ## Usage
///
/// ```swift
/// @Injected var modelManager: ModelManager
/// ```
@MainActor
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DependencyContainer, T>

    var wrappedValue: T {
        DependencyContainer.shared[keyPath: keyPath]
    }

    init(_ keyPath: KeyPath<DependencyContainer, T>) {
        self.keyPath = keyPath
    }
}

// MARK: - Convenience Extensions

extension DependencyContainer {
    /// Convenience initializer for creating a test container with mock services
    static func forTesting(
        keychainService: KeychainServiceProtocol? = nil,
        dataManager: DataManager? = nil
    ) -> DependencyContainer {
        let container = DependencyContainer()
        if let keychain = keychainService {
            container.register(keychainService: keychain)
        }
        if let data = dataManager {
            container.register(dataManager: data)
        }
        return container
    }
}
