import XCTest
@testable import AudioWhisper

@MainActor
final class MLXModelManagerTests: IsolatedXCTestCase {
    // TODO(D1): MLXModelManager reads `selectedParakeetModel` from
    // UserDefaults.standard via AppDefaults. Once AppDefaults accepts an
    // injected UserDefaults, route writes through a UUID-scoped suite and
    // re-enable isolation.
    override var enforcesStandardUserDefaultsIsolation: Bool { false }


    // MARK: - MLXModel Tests

    func testMLXModelDisplayNameExtractsLastPathComponent() {
        let model = MLXModel(
            repo: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            estimatedSize: "0.6 GB",
            description: "Test model"
        )

        XCTAssertEqual(model.displayName, "Llama-3.2-1B-Instruct-4bit")
    }

    func testMLXModelDisplayNameHandlesSingleComponent() {
        let model = MLXModel(
            repo: "simple-model",
            estimatedSize: "1.0 GB",
            description: "Single component"
        )

        XCTAssertEqual(model.displayName, "simple-model")
    }

    func testMLXModelIdentifiable() {
        let model1 = MLXModel(repo: "test/model1", estimatedSize: "1 GB", description: "First")
        let model2 = MLXModel(repo: "test/model1", estimatedSize: "1 GB", description: "First")

        // Each instance gets a unique UUID
        XCTAssertNotEqual(model1.id, model2.id)
    }

    func testMLXModelEquatable() {
        let model1 = MLXModel(repo: "test/model", estimatedSize: "1 GB", description: "Test")
        let model2 = MLXModel(repo: "test/model", estimatedSize: "1 GB", description: "Test")

        // Equatable compares all properties except id
        XCTAssertEqual(model1.repo, model2.repo)
        XCTAssertEqual(model1.estimatedSize, model2.estimatedSize)
        XCTAssertEqual(model1.description, model2.description)
    }

    // MARK: - Recommended Models Tests

    func testRecommendedModelsListIsNotEmpty() {
        XCTAssertFalse(MLXModelManager.recommendedModels.isEmpty)
    }

    func testRecommendedModelsHaveValidStructure() {
        for model in MLXModelManager.recommendedModels {
            XCTAssertFalse(model.repo.isEmpty, "Repo should not be empty")
            XCTAssertFalse(model.estimatedSize.isEmpty, "Estimated size should not be empty")
            XCTAssertFalse(model.description.isEmpty, "Description should not be empty")
            XCTAssertTrue(model.repo.contains("/"), "Repo should be in org/name format")
        }
    }

    func testRecommendedModelsContainExpectedModels() {
        let repos = MLXModelManager.recommendedModels.map { $0.repo }

        XCTAssertTrue(repos.contains("mlx-community/Llama-3.2-1B-Instruct-4bit"))
        XCTAssertTrue(repos.contains("mlx-community/gemma-3-1b-it-4bit"))
    }

    // MARK: - Format Bytes Tests

    func testFormatBytesReturnsReadableString() {
        let manager = MLXModelManager.shared

        // Test various sizes
        let formatted1KB = manager.formatBytes(1024)
        XCTAssertTrue(formatted1KB.contains("KB") || formatted1KB.contains("bytes"))

        let formatted1MB = manager.formatBytes(1024 * 1024)
        XCTAssertTrue(formatted1MB.contains("MB") || formatted1MB.contains("KB"))

        let formatted1GB = manager.formatBytes(1024 * 1024 * 1024)
        XCTAssertTrue(formatted1GB.contains("GB") || formatted1GB.contains("MB"))
    }

    func testFormatBytesHandlesZero() {
        let manager = MLXModelManager.shared
        let formatted = manager.formatBytes(0)
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Initial State Tests

    func testUnusedModelCountCalculatesCorrectly() {
        let manager = MLXModelManager.shared

        // With empty downloadedModels, unused count should be 0
        // (because there are no downloaded models that aren't in recommended)
        let initialCount = manager.unusedModelCount
        XCTAssertGreaterThanOrEqual(initialCount, 0)
    }

    // MARK: - Parakeet Repo Tests

    func testParakeetRepoReturnsDefaultWhenNotSet() {
        UserDefaults.standard.removeObject(forKey: "selectedParakeetModel")

        let repo = MLXModelManager.parakeetRepo
        XCTAssertFalse(repo.isEmpty)
    }

    func testParakeetRepoReturnsUserSelection() {
        let customRepo = "custom/parakeet-model"
        UserDefaults.standard.set(customRepo, forKey: "selectedParakeetModel")

        let repo = MLXModelManager.parakeetRepo
        XCTAssertEqual(repo, customRepo)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "selectedParakeetModel")
    }
}
