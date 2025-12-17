import Foundation
import Observation

private enum UsageMetricsConstants {
    static let defaultTypingWordsPerMinute: Double = 45.0
    static let averageCharactersPerWord: Double = 5.0
    static let maxDailyActivityDays: Int = 90 // Keep 90 days of daily activity
}

internal struct UsageSnapshot: Equatable {
    var totalSessions: Int
    var totalDuration: TimeInterval
    var totalWords: Int
    var totalCharacters: Int
    var lastUpdated: Date?
    /// Daily word counts keyed by date string (yyyy-MM-dd)
    var dailyActivity: [String: Int]

    static let empty = UsageSnapshot(
        totalSessions: 0,
        totalDuration: 0,
        totalWords: 0,
        totalCharacters: 0,
        lastUpdated: nil,
        dailyActivity: [:]
    )

    var averageSessionDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalDuration / Double(totalSessions)
    }

    var averageWordsPerSession: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(totalWords) / Double(totalSessions)
    }

    var wordsPerMinute: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalWords) / (totalDuration / 60.0)
    }

    var estimatedTypingDuration: TimeInterval {
        let typingMinutes = Double(totalWords) / UsageMetricsConstants.defaultTypingWordsPerMinute
        return typingMinutes * 60.0
    }

    var estimatedTimeSaved: TimeInterval {
        max(0, estimatedTypingDuration - totalDuration)
    }

    var keystrokesSaved: Int {
        Int(round(Double(totalWords) * UsageMetricsConstants.averageCharactersPerWord))
    }
}

@Observable
@MainActor
internal final class UsageMetricsStore {
    static let shared = UsageMetricsStore()

    static let defaultTypingWordsPerMinute: Double = UsageMetricsConstants.defaultTypingWordsPerMinute
    static let averageCharactersPerWord: Double = UsageMetricsConstants.averageCharactersPerWord

    private(set) var snapshot: UsageSnapshot

    private let defaults: UserDefaults

    private enum Keys {
        static let totalSessions = "usage.totalSessions"
        static let totalDuration = "usage.totalDuration"
        static let totalWords = "usage.totalWords"
        static let totalCharacters = "usage.totalCharacters"
        static let lastUpdated = "usage.lastUpdated"
        static let dailyActivity = "usage.dailyActivity"
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let dailyData = defaults.dictionary(forKey: Keys.dailyActivity) as? [String: Int] ?? [:]
        self.snapshot = UsageSnapshot(
            totalSessions: defaults.integer(forKey: Keys.totalSessions),
            totalDuration: defaults.double(forKey: Keys.totalDuration),
            totalWords: defaults.integer(forKey: Keys.totalWords),
            totalCharacters: defaults.integer(forKey: Keys.totalCharacters),
            lastUpdated: defaults.object(forKey: Keys.lastUpdated) as? Date,
            dailyActivity: dailyData
        )
    }

    func recordSession(duration: TimeInterval?, wordCount: Int, characterCount: Int) {
        var updated = snapshot
        updated.totalSessions += 1
        if let duration = duration {
            updated.totalDuration += duration
        }
        updated.totalWords += wordCount
        updated.totalCharacters += characterCount
        updated.lastUpdated = Date()
        
        // Track daily activity
        let today = Self.dateFormatter.string(from: Date())
        updated.dailyActivity[today, default: 0] += wordCount
        
        // Cleanup old daily activity entries (keep last 90 days)
        updated.dailyActivity = cleanupOldDailyActivity(updated.dailyActivity)
        
        persist(updated)
    }
    
    private func cleanupOldDailyActivity(_ activity: [String: Int]) -> [String: Int] {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -UsageMetricsConstants.maxDailyActivityDays,
            to: Date()
        ) ?? Date()
        let cutoffString = Self.dateFormatter.string(from: cutoffDate)
        
        return activity.filter { key, _ in
            key >= cutoffString
        }
    }
    
    /// Get daily activity as Date -> Int dictionary for the last N days
    func getDailyActivity(days: Int = 28) -> [Date: Int] {
        let calendar = Calendar.current
        var result: [Date: Int] = [:]
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dateString = Self.dateFormatter.string(from: date)
            let startOfDay = calendar.startOfDay(for: date)
            result[startOfDay] = snapshot.dailyActivity[dateString] ?? 0
        }
        
        return result
    }
    
    /// Calculate current streak (consecutive days with activity)
    func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        while true {
            let dateString = Self.dateFormatter.string(from: currentDate)
            if let words = snapshot.dailyActivity[dateString], words > 0 {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }

    func rebuild(using records: [TranscriptionRecord]) {
        var rebuilt = UsageSnapshot.empty
        for record in records {
            rebuilt.totalSessions += 1
            if let duration = record.duration {
                rebuilt.totalDuration += duration
            }
            rebuilt.totalWords += record.wordCount
            rebuilt.totalCharacters += record.text.count
            
            // Rebuild daily activity from records
            let dateString = Self.dateFormatter.string(from: record.date)
            rebuilt.dailyActivity[dateString, default: 0] += record.wordCount
        }
        rebuilt.lastUpdated = Date()
        rebuilt.dailyActivity = cleanupOldDailyActivity(rebuilt.dailyActivity)
        persist(rebuilt)
    }

    func reset() {
        persist(.empty)
    }

    func bootstrapIfNeeded(dataManager: DataManagerProtocol = DataManager.shared) async {
        // If dailyActivity is empty but we have records, rebuild from records
        let needsDailyActivityBootstrap = snapshot.dailyActivity.isEmpty && dataManager.isHistoryEnabled
        let needsFullBootstrap = snapshot.totalSessions == 0 && snapshot.totalDuration == 0 && snapshot.totalWords == 0 && dataManager.isHistoryEnabled
        
        guard needsDailyActivityBootstrap || needsFullBootstrap else {
            return
        }

        let records = await dataManager.fetchAllRecordsQuietly()
        guard !records.isEmpty else { return }
        
        if needsFullBootstrap {
            rebuild(using: records)
        } else {
            // Just rebuild daily activity
            rebuildDailyActivity(using: records)
        }
    }
    
    /// Rebuild only daily activity from records without resetting other stats
    func rebuildDailyActivity(using records: [TranscriptionRecord]) {
        var updated = snapshot
        updated.dailyActivity = [:]
        
        for record in records {
            let dateString = Self.dateFormatter.string(from: record.date)
            updated.dailyActivity[dateString, default: 0] += record.wordCount
        }
        
        updated.dailyActivity = cleanupOldDailyActivity(updated.dailyActivity)
        persist(updated)
    }

    private func persist(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        defaults.set(snapshot.totalSessions, forKey: Keys.totalSessions)
        defaults.set(snapshot.totalDuration, forKey: Keys.totalDuration)
        defaults.set(snapshot.totalWords, forKey: Keys.totalWords)
        defaults.set(snapshot.totalCharacters, forKey: Keys.totalCharacters)
        defaults.set(snapshot.lastUpdated, forKey: Keys.lastUpdated)
        defaults.set(snapshot.dailyActivity, forKey: Keys.dailyActivity)
    }

    static func estimatedWordCount(for text: String) -> Int {
        let words = text.split { character in
            if character.isLetter || character.isNumber {
                return false
            }
            if character == "'" {
                return false
            }
            return true
        }
        return words.count
    }

#if DEBUG
    /// Helper for tests to set a deterministic snapshot without recording sessions.
    func setSnapshotForTesting(_ snapshot: UsageSnapshot) {
        persist(snapshot)
    }
#endif
}
