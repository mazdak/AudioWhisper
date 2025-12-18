import Foundation
import Observation
import SwiftUI

@Observable
internal final class CategoryStore {
    static let shared = CategoryStore()

    private(set) var categories: [CategoryDefinition]
    private var categoriesById: [String: CategoryDefinition]

    private let fileManager: FileManager
    private let storageURL: URL?

    init(fileManager: FileManager = .default, storageURL: URL? = nil) {
        self.fileManager = fileManager
        if let storageURL {
            self.storageURL = storageURL
        } else {
            self.storageURL = try? fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("AudioWhisper/categories.json", isDirectory: false)
        }

        let defaults = CategoryDefinition.defaults
        categories = defaults
        categoriesById = Dictionary(uniqueKeysWithValues: defaults.map { ($0.id, $0) })
        loadFromDiskIfNeeded()
    }

    func category(withId id: String) -> CategoryDefinition {
        categoriesById[id] ?? CategoryDefinition.fallback
    }

    func containsCategory(withId id: String) -> Bool {
        categoriesById[id] != nil
    }

    func upsert(_ category: CategoryDefinition) {
        if let existingIndex = categories.firstIndex(where: { $0.id == category.id }) {
            categories[existingIndex] = category
        } else {
            categories.append(category)
        }
        rebuildIndex()
        persist()
    }

    func delete(_ category: CategoryDefinition) {
        guard !category.isSystem else { return }
        categories.removeAll { $0.id == category.id }
        rebuildIndex()
        persist()
    }

    func resetToDefaults() {
        categories = CategoryDefinition.defaults
        rebuildIndex()
        persist()
    }

    // MARK: - Persistence

    private func loadFromDiskIfNeeded() {
        guard let storageURL,
              fileManager.fileExists(atPath: storageURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([CategoryDefinition].self, from: data)
            if !decoded.isEmpty {
                categories = decoded
                rebuildIndex()
            }
        } catch {
            // If loading fails, keep defaults and ignore.
        }
    }

    private func persist() {
        guard let storageURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(categories)
            let dir = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            // Best effort persistence; ignore failures silently for now.
        }
    }

    private func rebuildIndex() {
        categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }
}

#if DEBUG
extension CategoryStore {
    func reloadForPreviews() {
        categories = CategoryDefinition.defaults
        rebuildIndex()
    }
}
#endif
