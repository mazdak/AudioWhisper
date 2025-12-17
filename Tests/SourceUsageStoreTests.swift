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
                iconData: Data([0x0A]),
                fallbackSymbolName: nil
            ),
            "com.persist.b": SourceUsageStats(
                bundleIdentifier: "com.persist.b",
                displayName: "Persist B",
                totalWords: 10,
                totalCharacters: 50,
                sessionCount: 2,
                lastUsed: now,
                iconData: nil,
                fallbackSymbolName: "tray"
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
        XCTAssertEqual(restored.last?.iconData, Data([0x0A]))
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
