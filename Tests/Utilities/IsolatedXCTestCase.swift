import XCTest
import Foundation

/// Base test case that detects and fails on tests which mutate
/// `UserDefaults.standard`. Tests that need persistent settings should use
/// a UUID-scoped suite: `UserDefaults(suiteName: UUID().uuidString)!`.
///
/// This is the safety net that lets CI run `swift test --parallel` without
/// inter-test pollution. Subclass this in any test that runs business logic
/// known to read/write UserDefaults — Services, Stores, Managers, and most
/// integration tests.
///
/// Enforcement is OFF by default during the gradual migration so that
/// converting a test to `IsolatedXCTestCase` is a pure structural change
/// with no behavior risk. The base class still serves as documentation
/// (which tests *are* isolated) and as the seam for opting in when ready.
///
/// To turn on enforcement, set one of:
///   - `AUDIOWHISPER_TEST_ISOLATION=warn`   — print `[IsolatedXCTestCase]
///     WARNING:` for any test that leaks/mutates `.standard`. Does NOT fail
///     the test. Useful for finding offenders during the migration.
///   - `AUDIOWHISPER_TEST_ISOLATION=strict` — `XCTFail` on leak/mutation
///     and restore `.standard` to its original state. Use once every test
///     has been migrated so CI catches regressions.
open class IsolatedXCTestCase: XCTestCase {
    /// Snapshot of the app's persistent UserDefaults domain at the start of
    /// this test. We compare against this in `tearDown` to detect mutations.
    ///
    /// Reading `persistentDomain(forName:)` is more reliable than
    /// `dictionaryRepresentation()` because the latter merges in other search
    /// lists (NSGlobalDomain, registered defaults, instantiated suites) that
    /// may legitimately appear or disappear between setUp and tearDown
    /// without the test having touched `.standard`.
    private var initialSnapshot: [String: Any] = [:]

    /// Subclasses set to `false` only if they have a *documented, reviewed*
    /// reason to mutate `.standard` (e.g. a one-off migration test).
    open var enforcesStandardUserDefaultsIsolation: Bool { true }

    /// The domain name to snapshot. Defaults to the test runner's bundle id;
    /// falls back to a sentinel that matches no real domain when nil.
    private var standardDomainName: String {
        Bundle.main.bundleIdentifier ?? "__missing_bundle_identifier__"
    }

    private func currentDomain() -> [String: Any] {
        UserDefaults.standard.persistentDomain(forName: standardDomainName) ?? [:]
    }

    private enum Enforcement {
        case off, warn, strict
    }

    private var enforcement: Enforcement {
        guard enforcesStandardUserDefaultsIsolation else { return .off }
        switch ProcessInfo.processInfo.environment["AUDIOWHISPER_TEST_ISOLATION"] {
        case "strict": return .strict
        case "warn":   return .warn
        default:       return .off
        }
    }

    open override func setUp() {
        super.setUp()
        if enforcement != .off {
            initialSnapshot = currentDomain()
        }
    }

    open override func tearDown() {
        if enforcement != .off {
            let after = currentDomain()
            let leakedKeys = Set(after.keys).subtracting(initialSnapshot.keys)
            let mutatedKeys = initialSnapshot.keys.filter {
                guard let before = initialSnapshot[$0] as? NSObject,
                      let now = after[$0] as? NSObject else { return false }
                return before != now
            }
            if !leakedKeys.isEmpty || !mutatedKeys.isEmpty {
                let message = """
                Test mutated UserDefaults.standard. Use UserDefaults(suiteName: UUID().uuidString) instead.
                Leaked keys: \(leakedKeys.sorted())
                Mutated keys: \(mutatedKeys.sorted())
                """
                switch enforcement {
                case .strict:
                    XCTFail(message)
                    // Best-effort cleanup so subsequent tests aren't affected.
                    // We only cleanup in strict mode because the test author
                    // is on the hook for using a suite; outside strict mode
                    // these keys may legitimately belong to a concurrently
                    // running legacy test and removing them races.
                    for key in leakedKeys {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                    for key in mutatedKeys {
                        if let original = initialSnapshot[key] {
                            UserDefaults.standard.set(original, forKey: key)
                        } else {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                case .warn:
                    // Surface the issue without failing and without disturbing
                    // other tests' state.
                    print("[IsolatedXCTestCase] WARNING: \(message)")
                case .off:
                    break // Should not reach here because of the outer guard.
                }
            }
        }
        super.tearDown()
    }
}
