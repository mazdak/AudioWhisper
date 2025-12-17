import Foundation
import Observation

@Observable
internal final class AppCategoryManager {
    static let shared = AppCategoryManager()

    private let userDefaultsKey = "appCategoryMappings"
    private let defaults: UserDefaults
    private let categoryStore: CategoryStore

    // Built-in mappings (can be overridden by user)
    private static let builtInMappings: [String: String] = [
        // Terminal
        "com.mitchellh.ghostty": "terminal",
        "com.apple.Terminal": "terminal",
        "com.googlecode.iterm2": "terminal",
        "net.kovidgoyal.kitty": "terminal",
        "co.zeit.hyper": "terminal",
        "com.github.wez.wezterm": "terminal",

        // Coding
        "com.microsoft.VSCode": "coding",
        "com.todesktop.230313mzl4w4u92": "coding", // Cursor
        "dev.zed.Zed": "coding",
        "com.apple.dt.Xcode": "coding",
        "com.sublimetext.4": "coding",
        "com.jetbrains.intellij": "coding",
        "com.jetbrains.pycharm": "coding",
        "com.jetbrains.WebStorm": "coding",
        "com.jetbrains.goland": "coding",
        "abnerworks.Typora": "coding",

        // Chat
        "com.tinyspeck.slackmacgap": "chat",
        "com.hnc.Discord": "chat",
        "us.zoom.xos": "chat",
        "com.apple.MobileSMS": "chat",
        "ru.keepcoder.Telegram": "chat",
        "net.whatsapp.WhatsApp": "chat",
        "com.microsoft.teams2": "chat",

        // Email
        "com.apple.mail": "email",
        "com.microsoft.Outlook": "email",
        "com.readdle.smartemail-Mac": "email", // Spark
        "com.superhuman.electron": "email",
        "com.google.Gmail": "email",
        "com.freron.MailMate": "email",

        // Writing
        "com.apple.Notes": "writing",
        "md.obsidian": "writing",
        "notion.id": "writing",
        "com.notion.id": "writing",
        "com.apple.iWork.Pages": "writing",
        "com.microsoft.Word": "writing",

        // Browsers default to general
        "com.google.Chrome": "general",
        "com.apple.Safari": "general",
        "company.thebrowser.Browser": "general", // Arc
        "org.mozilla.firefox": "general",
    ]

    private(set) var userMappings: [String: String] = [:]

    init(defaults: UserDefaults = .standard, categoryStore: CategoryStore = .shared) {
        self.defaults = defaults
        self.categoryStore = categoryStore
        loadUserMappings()
    }

    // MARK: - Public API

    var availableCategories: [CategoryDefinition] {
        categoryStore.categories
    }

    func category(for bundleId: String) -> CategoryDefinition {
        let categoryId = categoryId(for: bundleId)
        return categoryStore.category(withId: categoryId)
    }

    func categoryId(for bundleId: String) -> String {
        if let userRaw = userMappings[bundleId], categoryStore.containsCategory(withId: userRaw) {
            return userRaw
        }
        return Self.builtInMappings[bundleId] ?? CategoryDefinition.fallback.id
    }

    func setCategory(_ category: CategoryDefinition, for bundleId: String) {
        setCategory(id: category.id, for: bundleId)
    }

    func setCategory(id categoryId: String, for bundleId: String) {
        guard categoryStore.containsCategory(withId: categoryId) else { return }
        userMappings[bundleId] = categoryId
        saveUserMappings()
    }

    func resetToDefault(for bundleId: String) {
        userMappings.removeValue(forKey: bundleId)
        saveUserMappings()
    }

    func isUserOverridden(_ bundleId: String) -> Bool {
        return userMappings[bundleId] != nil
    }

    // MARK: - Persistence

    private func loadUserMappings() {
        if let data = defaults.dictionary(forKey: userDefaultsKey) as? [String: String] {
            userMappings = data
        }
    }

    private func saveUserMappings() {
        defaults.set(userMappings, forKey: userDefaultsKey)
    }
}
