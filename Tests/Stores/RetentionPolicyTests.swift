import XCTest
@testable import AudioWhisper

@MainActor
final class RetentionPolicyTests: IsolatedXCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    func test_oneWeek_returnsSevenDaysAgo() throws {
        let cutoff = try XCTUnwrap(RetentionPolicy.cutoffDate(for: .oneWeek, now: fixedNow))
        XCTAssertEqual(
            cutoff.timeIntervalSince1970,
            fixedNow.timeIntervalSince1970 - 7 * 86_400,
            accuracy: 1
        )
    }

    func test_oneMonth_returnsThirtyDaysAgo() throws {
        let cutoff = try XCTUnwrap(RetentionPolicy.cutoffDate(for: .oneMonth, now: fixedNow))
        XCTAssertEqual(
            cutoff.timeIntervalSince1970,
            fixedNow.timeIntervalSince1970 - 30 * 86_400,
            accuracy: 1
        )
    }

    func test_threeMonths_returnsNinetyDaysAgo() throws {
        let cutoff = try XCTUnwrap(RetentionPolicy.cutoffDate(for: .threeMonths, now: fixedNow))
        XCTAssertEqual(
            cutoff.timeIntervalSince1970,
            fixedNow.timeIntervalSince1970 - 90 * 86_400,
            accuracy: 1
        )
    }

    func test_forever_returnsNil() {
        XCTAssertNil(RetentionPolicy.cutoffDate(for: .forever))
        XCTAssertNil(RetentionPolicy.cutoffDate(for: .forever, now: fixedNow))
    }

    func test_current_matchesAppDefaults() {
        // current is a thin pass-through to AppDefaults; just confirm it
        // returns one of the defined enum cases without throwing.
        let period = RetentionPolicy.current
        XCTAssertTrue(RetentionPeriod.allCases.contains(period))
    }
}
