import Foundation

internal enum ResourceLocator {
    /// Locates a bundled resource across common packaging modes:
    /// - `.app` bundle (copied into `Bundle.main`)
    /// - SwiftPM resources (`Bundle.module`)
    /// - SwiftPM resource bundle (historical fallback for `swift run`)
    /// - Dev fallback path (relative to current directory)
    static func url(forResource name: String, withExtension ext: String, devRelativePath: String? = nil) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        if let url = Bundle.module.url(forResource: name, withExtension: ext) {
            return url
        }

        if let resourceBundleURL = Bundle.main.url(forResource: "AudioWhisper_AudioWhisper", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let url = resourceBundle.url(forResource: name, withExtension: ext) {
            return url
        }

        if let devRelativePath {
            let devPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(devRelativePath)
                .path
            if FileManager.default.fileExists(atPath: devPath) {
                return URL(fileURLWithPath: devPath)
            }
        }

        return nil
    }

    static func pythonScriptURL(named name: String) -> URL? {
        url(forResource: name, withExtension: "py", devRelativePath: "Sources/\(name).py")
    }
}

