import Foundation
import AppKit
import Observation

internal struct SourceAppInfo: Equatable {
    let bundleIdentifier: String
    let displayName: String
    let iconData: Data?
    let fallbackSymbolName: String?
    
    static var unknown: SourceAppInfo {
        SourceAppInfo(
            bundleIdentifier: "unknown",
            displayName: "Background trigger",
            iconData: nil,
            fallbackSymbolName: "questionmark.app"
        )
    }
    
    static func from(app: NSRunningApplication) -> SourceAppInfo? {
        guard let bundleId = app.bundleIdentifier else {
            return nil
        }
        let name = app.localizedName ?? bundleId
        let iconData = SourceAppInfo.pngData(from: app.icon)
        return SourceAppInfo(
            bundleIdentifier: bundleId,
            displayName: name,
            iconData: iconData,
            fallbackSymbolName: nil
        )
    }
    
    private static func pngData(from image: NSImage?) -> Data? {
        guard let tiffData = image?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

internal struct SourceUsageStats: Codable, Identifiable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    var displayName: String
    var totalWords: Int
    var totalCharacters: Int
    var sessionCount: Int
    var lastUsed: Date
    var iconData: Data?
    var fallbackSymbolName: String?
    
    var initials: String {
        let components = displayName.split(separator: " ")
        let chars: [Character] = components.prefix(2).compactMap { $0.first }
        if chars.isEmpty, let first = displayName.first {
            return String(first)
        }
        return String(chars)
    }
    
    func nsImage() -> NSImage? {
        guard let iconData = iconData else { return nil }
        return NSImage(data: iconData)
    }
}

@Observable
@MainActor
internal final class SourceUsageStore {
    static let shared = SourceUsageStore()
    
    private let defaults: UserDefaults
    private let storageKey = "sourceUsage.stats"
    private let maxSources = 50
    
    private(set) var orderedStats: [SourceUsageStats] = []
    private var statsByBundle: [String: SourceUsageStats] = [:]
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode([String: SourceUsageStats].self, from: data) {
                statsByBundle = decoded
                orderedStats = decoded.values.sorted(by: defaultSort)
                return
            }
        }
        statsByBundle = [:]
        orderedStats = []
    }
    
    func recordUsage(for info: SourceAppInfo, words: Int, characters: Int) {
        guard words > 0 else { return }
        var existing = statsByBundle[info.bundleIdentifier] ?? SourceUsageStats(
            bundleIdentifier: info.bundleIdentifier,
            displayName: info.displayName,
            totalWords: 0,
            totalCharacters: 0,
            sessionCount: 0,
            lastUsed: Date(),
            iconData: info.iconData,
            fallbackSymbolName: info.fallbackSymbolName
        )
        existing.totalWords += words
        existing.totalCharacters += characters
        existing.sessionCount += 1
        existing.lastUsed = Date()
        if existing.displayName != info.displayName {
            existing.displayName = info.displayName
        }
        if existing.iconData == nil {
            existing.iconData = info.iconData
        }
        if existing.fallbackSymbolName == nil {
            existing.fallbackSymbolName = info.fallbackSymbolName
        }
        statsByBundle[existing.bundleIdentifier] = existing
        trimIfNeeded()
        refreshOrderedStats()
        persist()
    }
    
    func topSources(limit: Int) -> [SourceUsageStats] {
        Array(orderedStats.prefix(limit))
    }
    
    func allSources() -> [SourceUsageStats] {
        orderedStats
    }
    
    private func trimIfNeeded() {
        guard statsByBundle.count > maxSources else { return }
        let surplus = statsByBundle.count - maxSources
        let candidates = orderedStats.reversed()
        for stat in candidates.prefix(surplus) {
            statsByBundle[stat.bundleIdentifier] = nil
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(statsByBundle) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func refreshOrderedStats() {
        orderedStats = statsByBundle.values.sorted(by: defaultSort)
    }
    
    private var defaultSort: (SourceUsageStats, SourceUsageStats) -> Bool {
        { lhs, rhs in
            if lhs.totalWords == rhs.totalWords {
                return lhs.lastUsed > rhs.lastUsed
            }
            return lhs.totalWords > rhs.totalWords
        }
    }

    /// Clears all persisted source usage stats.
    func reset() {
        statsByBundle = [:]
        orderedStats = []
        defaults.removeObject(forKey: storageKey)
    }

    func resetForTesting() {
        reset()
    }
}
