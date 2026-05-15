import Foundation

/// One-time setup state and rollout flags. These keys track whether the user
/// has been through a particular onboarding/migration step. Most are write-once.
extension AppDefaults {

    // MARK: - Setup State

    static var hasSetupParakeet: Bool {
        get { defaults.bool(forKey: Key.hasSetupParakeet.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasSetupParakeet.rawValue) }
    }

    static var hasSetupLocalLLM: Bool {
        get { defaults.bool(forKey: Key.hasSetupLocalLLM.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasSetupLocalLLM.rawValue) }
    }

    static var hasCompletedWelcome: Bool {
        get { defaults.bool(forKey: Key.hasCompletedWelcome.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedWelcome.rawValue) }
    }

    static var lastWelcomeVersion: String {
        get { defaults.string(forKey: Key.lastWelcomeVersion.rawValue) ?? "0" }
        set { defaults.set(newValue, forKey: Key.lastWelcomeVersion.rawValue) }
    }

    static var hasShownFirstModelUseHint: Bool {
        get { defaults.bool(forKey: Key.hasShownFirstModelUseHint.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasShownFirstModelUseHint.rawValue) }
    }

    /// One-time migration flag: whether corrupted Saved Application State was cleaned up.
    static var hasCleanedWindowState: Bool {
        get { defaults.bool(forKey: Key.hasCleanedWindowState.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCleanedWindowState.rawValue) }
    }
}
