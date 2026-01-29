import XCTest
@testable import AudioWhisper

@MainActor
final class SourceUsageStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: SourceUsageStore!

    override func setUp() {
        super.setUp()
        suiteName = "SourceUsageStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SourceUsageStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordUsageAccumulatesAndUpdatesMetadata() {
        let initialInfo = makeInfo(bundleId: "com.test.app", name: "Test App", iconByte: 0x01)

        store.recordUsage(for: initialInfo, words: 50, characters: 200)

        guard let firstStat = store.allSources().first else {
            return XCTFail("Expected first stat")
        }
        XCTAssertEqual(firstStat.totalWords, 50)
        XCTAssertEqual(firstStat.totalCharacters, 200)
        XCTAssertEqual(firstStat.sessionCount, 1)
        XCTAssertEqual(firstStat.displayName, "Test App")
        XCTAssertEqual(firstStat.iconData, Data([0x01]))
        XCTAssertNil(firstStat.fallbackSymbolName)

        let updatedInfo = makeInfo(bundleId: "com.test.app", name: "Test App Renamed", iconByte: nil, fallbackSymbol: "doc")
        store.recordUsage(for: updatedInfo, words: 10, characters: 40)

        guard let updatedStat = store.allSources().first else {
            return XCTFail("Expected updated stat")
        }
        XCTAssertEqual(updatedStat.displayName, "Test App Renamed")
        XCTAssertEqual(updatedStat.totalWords, 60)
        XCTAssertEqual(updatedStat.totalCharacters, 240)
        XCTAssertEqual(updatedStat.sessionCount, 2)
        XCTAssertEqual(updatedStat.iconData, Data([0x01]), "Icon should not be replaced when nil provided")
        XCTAssertEqual(updatedStat.fallbackSymbolName, "doc")
    }

    func testRecordUsageIgnoresZeroWords() {
        let info = makeInfo(bundleId: "com.test.none", name: "No Words")

        store.recordUsage(for: info, words: 0, characters: 10)

        XCTAssertTrue(store.allSources().isEmpty)
    }

    func testTopSourcesSortsByWordsThenRecency() {
        let appA = makeInfo(bundleId: "com.test.a", name: "App A")
        let appB = makeInfo(bundleId: "com.test.b", name: "App B")

        store.recordUsage(for: appA, words: 10, characters: 50)
        usleep(10_000) // ensure distinct timestamps
        store.recordUsage(for: appB, words: 10, characters: 60)

        let tiedOrder = store.topSources(limit: 2)
        XCTAssertEqual(tiedOrder.first?.bundleIdentifier, "com.test.b", "More recent usage with equal words should come first")

        let appC = makeInfo(bundleId: "com.test.c", name: "App C")
        store.recordUsage(for: appC, words: 20, characters: 80)

        let reordered = store.topSources(limit: 1)
        XCTAssertEqual(reordered.first?.bundleIdentifier, "com.test.c", "Highest word count should sort first")
    }

    func testTrimKeepsMostUsedWhenExceedingLimit() {
        for i in 0...50 { // 51 sources
            let info = makeInfo(bundleId: "com.test.\(i)", name: "App \(i)")
            store.recordUsage(for: info, words: i + 1, characters: 1)
        }

        let all = store.allSources()
        XCTAssertEqual(all.count, 50)
        XCTAssertFalse(all.contains { $0.bundleIdentifier == "com.test.0" }, "Least-used source should be trimmed")
        XCTAssertTrue(all.contains { $0.bundleIdentifier == "com.test.50" }, "Most-used source should remain")
    }

    func testInitRestoresFromPersistedDefaults() {
        let now = Date()
        let older = now.addingTimeInterval(-100)
        let stats: [String: SourceUsageStats] = [
            "com.persist.a": SourceUsageStats(
                bundleIdentifier: "com.persist.a",
                displayName: "Persist A",
                totalWords: 5,
                totalCharacters: 25,
                sessionCount: 1,
                lastUsed: older,
                fallbackSymbolName: nil,
                iconData: Data([0x0A])
            ),
            "com.persist.b": SourceUsageStats(
                bundleIdentifier: "com.persist.b",
                displayName: "Persist B",
                totalWords: 10,
                totalCharacters: 50,
                sessionCount: 2,
                lastUsed: now,
                fallbackSymbolName: "tray",
                iconData: nil
            )
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(stats)
        defaults.set(data, forKey: "sourceUsage.stats")

        store = SourceUsageStore(defaults: defaults)

        let restored = store.allSources()
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.first?.bundleIdentifier, "com.persist.b", "Higher word count should be ordered first on load")
        XCTAssertEqual(restored.first?.fallbackSymbolName, "tray")
        // Note: iconData is intentionally excluded from Codable (see SourceUsageStats.CodingKeys)
        // to prevent UserDefaults overflow. Icons are loaded dynamically from bundle when needed.
        XCTAssertNil(restored.last?.iconData, "iconData is not persisted to avoid UserDefaults overflow")
    }

    func testRebuildFromTranscriptionRecords() {
        // First add some usage directly
        let info = makeInfo(bundleId: "com.test.old", name: "Old App")
        store.recordUsage(for: info, words: 100, characters: 500)
        XCTAssertEqual(store.allSources().count, 1)

        // Create transcription records
        let records = [
            TranscriptionRecord(
                text: "Hello world from app A",
                provider: .local,
                duration: 5.0,
                modelUsed: nil,
                wordCount: 50,
                characterCount: 200,
                sourceAppBundleId: "com.test.a",
                sourceAppName: "App A",
                sourceAppIconData: Data([0x01])
            ),
            TranscriptionRecord(
                text: "More text from app A",
                provider: .local,
                duration: 3.0,
                modelUsed: nil,
                wordCount: 30,
                characterCount: 120,
                sourceAppBundleId: "com.test.a",
                sourceAppName: "App A",
                sourceAppIconData: nil
            ),
            TranscriptionRecord(
                text: "Text from app B",
                provider: .parakeet,
                duration: 2.0,
                modelUsed: nil,
                wordCount: 20,
                characterCount: 80,
                sourceAppBundleId: "com.test.b",
                sourceAppName: "App B",
                sourceAppIconData: Data([0x02])
            )
        ]

        // Rebuild from records
        store.rebuild(using: records)

        // Verify the old usage is gone and new stats are correct
        let sources = store.allSources()
        XCTAssertEqual(sources.count, 2)

        // App A should have combined stats
        let appA = sources.first { $0.bundleIdentifier == "com.test.a" }
        XCTAssertNotNil(appA)
        XCTAssertEqual(appA?.totalWords, 80) // 50 + 30
        XCTAssertEqual(appA?.totalCharacters, 320) // 200 + 120
        XCTAssertEqual(appA?.sessionCount, 2)
        XCTAssertEqual(appA?.displayName, "App A")
        XCTAssertEqual(appA?.iconData, Data([0x01]))

        // App B should have its stats
        let appB = sources.first { $0.bundleIdentifier == "com.test.b" }
        XCTAssertNotNil(appB)
        XCTAssertEqual(appB?.totalWords, 20)
        XCTAssertEqual(appB?.totalCharacters, 80)
        XCTAssertEqual(appB?.sessionCount, 1)

        // Old app should be gone
        XCTAssertNil(sources.first { $0.bundleIdentifier == "com.test.old" })
    }

    func testRebuildWithEmptyRecords() {
        // First add some usage
        let info = makeInfo(bundleId: "com.test.app", name: "Test App")
        store.recordUsage(for: info, words: 100, characters: 500)
        XCTAssertEqual(store.allSources().count, 1)

        // Rebuild with empty array
        store.rebuild(using: [])

        // All stats should be cleared
        XCTAssertTrue(store.allSources().isEmpty)
    }

    func testRebuildIgnoresRecordsWithoutBundleId() {
        let records = [
            TranscriptionRecord(
                text: "Text without bundle",
                provider: .local,
                duration: 5.0,
                modelUsed: nil,
                wordCount: 50,
                characterCount: 200,
                sourceAppBundleId: nil,
                sourceAppName: nil,
                sourceAppIconData: nil
            ),
            TranscriptionRecord(
                text: "Text with empty bundle",
                provider: .local,
                duration: 5.0,
                modelUsed: nil,
                wordCount: 30,
                characterCount: 120,
                sourceAppBundleId: "",
                sourceAppName: "Empty Bundle",
                sourceAppIconData: nil
            )
        ]

        store.rebuild(using: records)

        XCTAssertTrue(store.allSources().isEmpty)
    }

    private func makeInfo(bundleId: String, name: String, iconByte: UInt8? = nil, fallbackSymbol: String? = nil) -> SourceAppInfo {
        let iconData = iconByte.map { Data([$0]) }
        return SourceAppInfo(
            bundleIdentifier: bundleId,
            displayName: name,
            iconData: iconData,
            fallbackSymbolName: fallbackSymbol
        )
    }
}
