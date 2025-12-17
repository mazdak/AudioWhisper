import XCTest
@testable import AudioWhisper

@MainActor
final class AppCategoryManagerTests: XCTestCase {
    private var manager: AppCategoryManager!
    private var defaults: UserDefaults!
    private var categoryStore: CategoryStore!
    private var tempURL: URL!
    private let suiteName = "com.audiowhisper.tests.categories"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")

        categoryStore = CategoryStore(fileManager: .default, storageURL: tempURL)
        categoryStore.resetToDefaults()
        manager = AppCategoryManager(defaults: defaults, categoryStore: categoryStore)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        defaults.removePersistentDomain(forName: suiteName)
        manager = nil
        defaults = nil
        categoryStore = nil
        tempURL = nil
        super.tearDown()
    }

    func testBuiltInMappingReturnsExpectedCategory() {
        XCTAssertEqual(manager.category(for: "com.apple.Terminal").id, "terminal")
        XCTAssertEqual(manager.category(for: "com.microsoft.VSCode").id, "coding")
        XCTAssertEqual(manager.category(for: "com.tinyspeck.slackmacgap").id, "chat")
        XCTAssertEqual(manager.category(for: "com.apple.mail").id, "email")
    }

    func testUnknownBundleDefaultsToGeneral() {
        XCTAssertEqual(manager.category(for: "com.example.unknown").id, "general")
    }

    func testUserOverrideTakesPrecedenceOverBuiltIn() {
        let bundleId = "com.google.Chrome" // Built-in defaults to general
        let coding = CategoryDefinition.defaults.first { $0.id == "coding" }!

        manager.setCategory(coding, for: bundleId)

        XCTAssertTrue(manager.isUserOverridden(bundleId))
        XCTAssertEqual(manager.category(for: bundleId).id, "coding")
    }

    func testResetToDefaultRestoresBuiltInCategory() {
        let bundleId = "com.apple.Terminal"
        let chat = CategoryDefinition.defaults.first { $0.id == "chat" }!

        manager.setCategory(chat, for: bundleId)
        XCTAssertEqual(manager.category(for: bundleId).id, "chat")

        manager.resetToDefault(for: bundleId)

        XCTAssertFalse(manager.isUserOverridden(bundleId))
        XCTAssertEqual(manager.category(for: bundleId).id, "terminal")
    }

    func testSetCategoryPersistsToUserDefaults() {
        let bundleId = "com.custom.editor"
        let writing = CategoryDefinition.defaults.first { $0.id == "writing" }!

        manager.setCategory(writing, for: bundleId)
        defaults.synchronize()

        let stored = defaults.dictionary(forKey: "appCategoryMappings") as? [String: String]
        XCTAssertEqual(stored?[bundleId], writing.id)
        XCTAssertEqual(manager.category(for: bundleId).id, "writing")
    }
}
