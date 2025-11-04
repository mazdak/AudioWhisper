import Foundation
import Combine

private enum UsageMetricsConstants {
    static let defaultTypingWordsPerMinute: Double = 45.0
    static let averageCharactersPerWord: Double = 5.0
}

struct UsageSnapshot: Equatable {
    var totalSessions: Int
    var totalDuration: TimeInterval
    var totalWords: Int
    var totalCharacters: Int
    var lastUpdated: Date?

    static let empty = UsageSnapshot(
        totalSessions: 0,
        totalDuration: 0,
        totalWords: 0,
        totalCharacters: 0,
        lastUpdated: nil
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

@MainActor
final class UsageMetricsStore: ObservableObject {
    static let shared = UsageMetricsStore()

    static let defaultTypingWordsPerMinute: Double = UsageMetricsConstants.defaultTypingWordsPerMinute
    static let averageCharactersPerWord: Double = UsageMetricsConstants.averageCharactersPerWord

    @Published private(set) var snapshot: UsageSnapshot

    private let defaults: UserDefaults

    private enum Keys {
        static let totalSessions = "usage.totalSessions"
        static let totalDuration = "usage.totalDuration"
        static let totalWords = "usage.totalWords"
        static let totalCharacters = "usage.totalCharacters"
        static let lastUpdated = "usage.lastUpdated"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshot = UsageSnapshot(
            totalSessions: defaults.integer(forKey: Keys.totalSessions),
            totalDuration: defaults.double(forKey: Keys.totalDuration),
            totalWords: defaults.integer(forKey: Keys.totalWords),
            totalCharacters: defaults.integer(forKey: Keys.totalCharacters),
            lastUpdated: defaults.object(forKey: Keys.lastUpdated) as? Date
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
        persist(updated)
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
        }
        rebuilt.lastUpdated = Date()
        persist(rebuilt)
    }

    func reset() {
        persist(.empty)
    }

    func bootstrapIfNeeded(dataManager: DataManagerProtocol = DataManager.shared) async {
        guard snapshot.totalSessions == 0,
              snapshot.totalDuration == 0,
              snapshot.totalWords == 0,
              dataManager.isHistoryEnabled else {
            return
        }

        let records = await dataManager.fetchAllRecordsQuietly()
        guard !records.isEmpty else { return }
        rebuild(using: records)
    }

    private func persist(_ snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        defaults.set(snapshot.totalSessions, forKey: Keys.totalSessions)
        defaults.set(snapshot.totalDuration, forKey: Keys.totalDuration)
        defaults.set(snapshot.totalWords, forKey: Keys.totalWords)
        defaults.set(snapshot.totalCharacters, forKey: Keys.totalCharacters)
        defaults.set(snapshot.lastUpdated, forKey: Keys.lastUpdated)
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
}
