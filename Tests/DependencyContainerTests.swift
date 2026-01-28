import XCTest
@testable import AudioWhisper

@MainActor
final class DependencyContainerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        DependencyContainer.shared.reset()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Default Service Tests

    func testModelManagerReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let modelManager = container.modelManager

        XCTAssertNotNil(modelManager)
        XCTAssertTrue(modelManager === ModelManager.shared)
    }

    func testMLXModelManagerReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let mlxManager = container.mlxModelManager

        XCTAssertNotNil(mlxManager)
        XCTAssertTrue(mlxManager === MLXModelManager.shared)
    }

    func testKeychainServiceReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let keychain = container.keychainService

        XCTAssertNotNil(keychain)
    }

    func testDataManagerReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let dataManager = container.dataManager

        XCTAssertNotNil(dataManager)
        XCTAssertTrue(dataManager === DataManager.shared)
    }

    func testUsageMetricsStoreReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let metricsStore = container.usageMetricsStore

        XCTAssertNotNil(metricsStore)
        XCTAssertTrue(metricsStore === UsageMetricsStore.shared)
    }

    func testPermissionManagerReturnsSharedInstance() {
        let container = DependencyContainer.shared
        let permissionManager = container.permissionManager

        XCTAssertNotNil(permissionManager)
        XCTAssertTrue(permissionManager === PermissionManager.shared)
    }

    // MARK: - Custom Registration Tests

    func testRegisterCustomKeychainService() {
        let container = DependencyContainer.shared
        let mockKeychain = MockKeychainService()

        container.register(keychainService: mockKeychain)

        XCTAssertTrue(container.keychainService is MockKeychainService)
    }

    func testResetClearsCustomRegistrations() {
        let container = DependencyContainer.shared
        let mockKeychain = MockKeychainService()

        container.register(keychainService: mockKeychain)
        XCTAssertTrue(container.keychainService is MockKeychainService)

        container.reset()

        // After reset, should return the default shared instance
        XCTAssertTrue(container.keychainService === KeychainService.shared)
    }

    // MARK: - Test Container Factory Tests

    func testForTestingCreatesContainerWithMockKeychain() {
        let mockKeychain = MockKeychainService()
        let container = DependencyContainer.forTesting(keychainService: mockKeychain)

        XCTAssertTrue(container.keychainService is MockKeychainService)
    }

    func testForTestingWithNilParametersUsesDefaults() {
        let container = DependencyContainer.forTesting()

        // Should use default implementations when nil is passed
        XCTAssertNotNil(container.keychainService)
    }

    // MARK: - Thread Safety Tests

    func testMultipleAccessesReturnSameInstance() async {
        let container = DependencyContainer.shared

        var managers: [ModelManager] = []

        for _ in 0..<10 {
            managers.append(container.modelManager)
        }

        // All should be the same instance
        let first = managers.first
        for manager in managers {
            XCTAssertTrue(manager === first)
        }
    }
}
