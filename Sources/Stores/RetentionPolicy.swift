import Foundation

/// Defines how long transcription history is kept. The single source of
/// truth for retention cutoff dates and pruning logic — formerly lived
/// inside `DataManager`.
///
/// The pruning itself remains in `DataManager` (it owns the `ModelContext`).
/// Only the policy/date computation lives here so it can be unit-tested in
/// isolation and reused by future surfaces (export, diagnostics, etc.).
internal enum RetentionPolicy {
    /// Read from `AppDefaults.transcriptionRetentionPeriod`, which already
    /// returns a typed `RetentionPeriod` enum.
    static var current: RetentionPeriod {
        AppDefaults.transcriptionRetentionPeriod
    }

    /// The cutoff date for the given period — records older than this should
    /// be pruned. `nil` means "keep everything" (`.forever`).
    ///
    /// - Parameters:
    ///   - period: The retention window to apply.
    ///   - now: Injectable "current time" for deterministic tests.
    static func cutoffDate(for period: RetentionPeriod, now: Date = Date()) -> Date? {
        guard let interval = period.timeInterval else { return nil }
        return now.addingTimeInterval(-interval)
    }
}
