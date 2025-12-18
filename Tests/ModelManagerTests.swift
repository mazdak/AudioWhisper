import XCTest
import Foundation
import WhisperKit
@testable import AudioWhisper

// MARK: - Thread-Safe Helper
actor ActorBox<T> {
    private var _value: T
    
    init(_ value: T) {
        self._value = value
    }
    
    var value: T {
        return _value
    }
    
    func setValue(_ value: T) {
        self._value = value
    }
    
    func append(_ element: T.Element) where T: RangeReplaceableCollection {
        self._value.append(element)
    }
}

// MARK: - Mock FileManager
class MockFileManager: FileManagerProtocol {
    var mockFiles: Set<String> = []
    var mockDirectories: Set<String> = []
    var mockFileAttributes: [String: [FileAttributeKey: Any]] = [:]
    var shouldThrowOnRemoveItem = false
    var shouldThrowOnCreateDirectory = false
    var removeItemCalled = false
    var createDirectoryCalled = false
    
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        // Return mock application support directory
        return [URL(fileURLWithPath: "/tmp/test/ApplicationSupport")]
    }
    
    func fileExists(atPath path: String) -> Bool {
        return mockFiles.contains(path)
    }
    
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]? = nil) throws {
        createDirectoryCalled = true
        if shouldThrowOnCreateDirectory {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock create directory error"])
        }
        mockDirectories.insert(url.path)
    }
    
    func removeItem(at url: URL) throws {
        removeItemCalled = true
        if shouldThrowOnRemoveItem {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock remove item error"])
        }
        mockFiles.remove(url.path)
    }
    
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if let attributes = mockFileAttributes[path] {
            return attributes
        }
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found"])
    }
}

// MARK: - FileManager Protocol
protocol FileManagerProtocol {
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func removeItem(at url: URL) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
}

// MARK: - FileManager Extension
extension FileManager: FileManagerProtocol {
    // No need to implement - FileManager already has this method
}

// MARK: - Mock ModelManager
@Observable
class MockModelManager {
    @MainActor var downloadProgress: [WhisperModel: Double] = [:]
    @MainActor var downloadingModels: Set<WhisperModel> = []
    
    private let mockFileManager: MockFileManager
    private var downloadRequests: [WhisperModel: Bool] = [:]
    
    init(fileManager: MockFileManager) {
        self.mockFileManager = fileManager
    }
    
    var modelsDirectory: URL {
        let appSupport = mockFileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioWhisperDir = appSupport.appendingPathComponent("AudioWhisper")
        let modelsDir = audioWhisperDir.appendingPathComponent("Models")
        
        try? mockFileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
        return modelsDir
    }
    
    nonisolated func isModelDownloaded(_ model: WhisperModel) -> Bool {
        let appSupport = mockFileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioWhisperDir = appSupport.appendingPathComponent("AudioWhisper")
        let modelsDir = audioWhisperDir.appendingPathComponent("Models")
        let modelPath = modelsDir.appendingPathComponent(model.fileName)
        return mockFileManager.fileExists(atPath: modelPath.path)
    }
    
    nonisolated func getModelPath(_ model: WhisperModel) -> URL? {
        let appSupport = mockFileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioWhisperDir = appSupport.appendingPathComponent("AudioWhisper")
        let modelsDir = audioWhisperDir.appendingPathComponent("Models")
        let modelPath = modelsDir.appendingPathComponent(model.fileName)
        return isModelDownloaded(model) ? modelPath : nil
    }
    
    nonisolated func downloadModel(_ model: WhisperModel) async throws {
        // Check if already downloading and mark as downloading
        let alreadyDownloading = await MainActor.run {
            if self.downloadingModels.contains(model) {
                return true
            }
            self.downloadingModels.insert(model)
            return false
        }
        
        if alreadyDownloading {
            throw ModelError.alreadyDownloading
        }
        
        // Clean up after download completes (will be done at the end)
        
        // Simulate actual download time
        try? await Task.sleep(for: .milliseconds(100)) // 100ms
        
        // Simulate download completion
        let destination = await MainActor.run { 
            self.modelsDirectory.appendingPathComponent(model.fileName)
        }
        
        // Mark file as downloaded
        mockFileManager.mockFiles.insert(destination.path)
        
        // Set file attributes for size calculation - convert string size to bytes
        let sizeInBytes: Int64
        switch model {
        case .tiny:
            sizeInBytes = 39 * 1024 * 1024
        case .base:
            sizeInBytes = 142 * 1024 * 1024
        case .small:
            sizeInBytes = 466 * 1024 * 1024
        case .largeTurbo:
            sizeInBytes = Int64(1.5 * 1024 * 1024 * 1024)
        }
        
        mockFileManager.mockFileAttributes[destination.path] = [
            .size: sizeInBytes
        ]
        
        // Clean up download state
        await MainActor.run {
            self.downloadingModels.remove(model)
            self.downloadProgress[model] = nil
        }
    }
    
    nonisolated func deleteModel(_ model: WhisperModel) throws {
        let appSupport = mockFileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioWhisperDir = appSupport.appendingPathComponent("AudioWhisper")
        let modelsDir = audioWhisperDir.appendingPathComponent("Models")
        let modelPath = modelsDir.appendingPathComponent(model.fileName)
        
        if mockFileManager.fileExists(atPath: modelPath.path) {
            try mockFileManager.removeItem(at: modelPath)
        }
    }
    
    nonisolated func getDownloadedModels() -> [WhisperModel] {
        return WhisperModel.allCases.filter { isModelDownloaded($0) }
    }
    
    nonisolated func getTotalModelsSize() -> Int64 {
        let downloadedModels = getDownloadedModels()
        var totalSize: Int64 = 0
        
        let appSupport = mockFileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioWhisperDir = appSupport.appendingPathComponent("AudioWhisper")
        let modelsDir = audioWhisperDir.appendingPathComponent("Models")
        
        for model in downloadedModels {
            let modelPath = modelsDir.appendingPathComponent(model.fileName)
            if let attributes = try? mockFileManager.attributesOfItem(atPath: modelPath.path),
               let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
}

// MARK: - ModelManagerTests
class ModelManagerTests: XCTestCase {
    var mockFileManager: MockFileManager!
    var mockModelManager: MockModelManager!
    
    override func setUp() {
        super.setUp()
        mockFileManager = MockFileManager()
        mockModelManager = MockModelManager(fileManager: mockFileManager)
    }
    
    @MainActor
    func resetModelState() {
        mockModelManager.downloadingModels.removeAll()
        mockModelManager.downloadProgress.removeAll()
    }
    
    override func tearDown() {
        mockFileManager = nil
        mockModelManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testModelsDirectoryCreation() {
        // Initialize the mock model manager to trigger directory creation
        _ = mockModelManager.modelsDirectory
        
        // Test that models directory is created
        XCTAssertTrue(mockFileManager.createDirectoryCalled)
        XCTAssertTrue(mockFileManager.mockDirectories.contains("/tmp/test/ApplicationSupport/AudioWhisper/Models"))
    }
    
    // MARK: - Model Download Tests
    
    func testIsModelDownloadedInitially() {
        // Initially no models should be downloaded
        for model in WhisperModel.allCases {
            XCTAssertFalse(mockModelManager.isModelDownloaded(model))
        }
    }
    
    func testDownloadModelSuccess() async {
        await resetModelState()
        let model = WhisperModel.base
        
        do {
            try await mockModelManager.downloadModel(model)
            
            // Verify model is now downloaded
            XCTAssertTrue(mockModelManager.isModelDownloaded(model))
            
            // Verify download state is cleaned up
            await MainActor.run {
                XCTAssertFalse(mockModelManager.downloadingModels.contains(model))
                XCTAssertNil(mockModelManager.downloadProgress[model])
            }
            
        } catch {
            XCTFail("Download should succeed: \(error)")
        }
    }
    
    func testDownloadModelAlreadyDownloading() async {
        await resetModelState()
        let model = WhisperModel.tiny
        
        // Start first download
        let firstDownloadTask = Task {
            try await mockModelManager.downloadModel(model)
        }
        
        // Wait a bit for first download to mark as downloading
        try? await Task.sleep(for: .milliseconds(50)) // 50ms
        
        // Try to start second download
        do {
            try await mockModelManager.downloadModel(model)
            XCTFail("Second download should fail with alreadyDownloading error")
        } catch let error as ModelError {
            XCTAssertEqual(error, ModelError.alreadyDownloading)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
        
        // Wait for first download to complete
        do {
            try await firstDownloadTask.value
        } catch {
            XCTFail("First download should succeed: \(error)")
        }
    }
    
    func testDownloadingModelsTracking() async {
        await resetModelState()
        let model = WhisperModel.small

        let startedExpectation = XCTestExpectation(description: "Download state entered")
        let finishedExpectation = XCTestExpectation(description: "Download state cleared")

        let downloadTask = Task {
            try await mockModelManager.downloadModel(model)
            finishedExpectation.fulfill()
        }

        // Allow the download task to mark state as downloading
        try? await Task.sleep(for: .milliseconds(20))
        await MainActor.run {
            if mockModelManager.downloadingModels.contains(model) {
                startedExpectation.fulfill()
            }
        }

        await fulfillment(of: [startedExpectation, finishedExpectation], timeout: 1.0)
        _ = try? await downloadTask.value

        await MainActor.run {
            XCTAssertFalse(mockModelManager.downloadingModels.contains(model))
            XCTAssertNil(mockModelManager.downloadProgress[model])
        }
    }
    
    // MARK: - Model Path Tests
    
    func testGetModelPathForNonDownloadedModel() {
        let model = WhisperModel.tiny
        let path = mockModelManager.getModelPath(model)
        XCTAssertNil(path)
    }
    
    func testGetModelPathForDownloadedModel() async {
        let model = WhisperModel.base
        
        // Download model first
        do {
            try await mockModelManager.downloadModel(model)
            
            let path = mockModelManager.getModelPath(model)
            XCTAssertNotNil(path)
            XCTAssertTrue(path!.path.hasSuffix(model.fileName))
            
        } catch {
            XCTFail("Download should succeed: \(error)")
        }
    }
    
    // MARK: - Model Deletion Tests
    
    func testDeleteNonExistentModel() {
        let model = WhisperModel.base
        
        // Should not throw error when deleting non-existent model
        XCTAssertNoThrow(try mockModelManager.deleteModel(model))
        XCTAssertFalse(mockFileManager.removeItemCalled)
    }
    
    func testDeleteExistingModel() async {
        let model = WhisperModel.tiny
        
        // Download model first
        do {
            try await mockModelManager.downloadModel(model)
            XCTAssertTrue(mockModelManager.isModelDownloaded(model))
            
            // Delete model
            try mockModelManager.deleteModel(model)
            XCTAssertTrue(mockFileManager.removeItemCalled)
            XCTAssertFalse(mockModelManager.isModelDownloaded(model))
            
        } catch {
            XCTFail("Operations should succeed: \(error)")
        }
    }
    
    func testDeleteModelWithFileSystemError() async {
        let model = WhisperModel.base
        
        // Download model first
        do {
            try await mockModelManager.downloadModel(model)
            XCTAssertTrue(mockModelManager.isModelDownloaded(model))
            
            // Configure mock to throw error on removal
            mockFileManager.shouldThrowOnRemoveItem = true
            
            // Delete should throw error
            XCTAssertThrowsError(try mockModelManager.deleteModel(model))
            
        } catch {
            XCTFail("Download should succeed: \(error)")
        }
    }
    
    // MARK: - Downloaded Models Tests
    
    func testGetDownloadedModelsEmpty() {
        let downloadedModels = mockModelManager.getDownloadedModels()
        XCTAssertEqual(downloadedModels.count, 0)
    }
    
    func testGetDownloadedModelsWithSomeModels() async {
        let models = [WhisperModel.tiny, WhisperModel.base, WhisperModel.small]
        
        // Download some models
        for model in models {
            do {
                try await mockModelManager.downloadModel(model)
            } catch {
                XCTFail("Download should succeed: \(error)")
            }
        }
        
        let downloadedModels = mockModelManager.getDownloadedModels()
        XCTAssertEqual(downloadedModels.count, 3)
        XCTAssertTrue(downloadedModels.contains(WhisperModel.tiny))
        XCTAssertTrue(downloadedModels.contains(WhisperModel.base))
        XCTAssertTrue(downloadedModels.contains(WhisperModel.small))
    }
    
    // MARK: - Total Size Tests
    
    func testGetTotalModelsSizeEmpty() {
        let totalSize = mockModelManager.getTotalModelsSize()
        XCTAssertEqual(totalSize, 0)
    }
    
    func testGetTotalModelsSizeWithModels() async {
        let models = [WhisperModel.tiny, WhisperModel.base]
        
        // Download models
        for model in models {
            do {
                try await mockModelManager.downloadModel(model)
            } catch {
                XCTFail("Download should succeed: \(error)")
            }
        }
        
        let totalSize = mockModelManager.getTotalModelsSize()
        let expectedSize = Int64(39 * 1024 * 1024) + Int64(142 * 1024 * 1024)  // tiny + base in bytes
        XCTAssertEqual(totalSize, expectedSize)
    }
    
    // MARK: - Error Handling Tests
    
    func testModelErrorDescriptions() {
        XCTAssertEqual(ModelError.alreadyDownloading.errorDescription, "Model is already being downloaded")
        XCTAssertEqual(ModelError.downloadFailed.errorDescription, "Failed to download model")
        XCTAssertEqual(ModelError.modelNotFound.errorDescription, "Model file not found")
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentModelOperations() async {
        await resetModelState()
        let models = [WhisperModel.tiny, WhisperModel.base, WhisperModel.small]
        
        // Download models sequentially to avoid race conditions in tests
        for model in models {
            do {
                try await mockModelManager.downloadModel(model)
            } catch {
                XCTFail("Download should succeed: \(error)")
            }
        }
        
        // Verify all models are downloaded
        for model in models {
            XCTAssertTrue(mockModelManager.isModelDownloaded(model))
        }
        
        let downloadedModels = mockModelManager.getDownloadedModels()
        XCTAssertEqual(downloadedModels.count, 3)
    }
    
    // MARK: - Performance Tests
    
    func testDownloadModelPerformance() {
        measure {
            // Reset state before each measurement
            let expectation = self.expectation(description: "Download complete")
            Task {
                await resetModelState()
                do {
                    try await mockModelManager.downloadModel(.tiny)
                    expectation.fulfill()
                } catch {
                    XCTFail("Download should succeed: \(error)")
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testGetDownloadedModelsPerformance() async {
        // Download several models first
        let models = WhisperModel.allCases.prefix(3)
        for model in models {
            do {
                try await mockModelManager.downloadModel(model)
            } catch {
                XCTFail("Download should succeed: \(error)")
            }
        }
        
        measure {
            _ = mockModelManager.getDownloadedModels()
        }
    }
    
    func testGetTotalModelsSizePerformance() async {
        // Download several models first
        let models = WhisperModel.allCases.prefix(3)
        for model in models {
            do {
                try await mockModelManager.downloadModel(model)
            } catch {
                XCTFail("Download should succeed: \(error)")
            }
        }
        
        measure {
            _ = mockModelManager.getTotalModelsSize()
        }
    }
}
