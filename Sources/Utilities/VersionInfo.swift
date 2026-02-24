import Foundation

struct VersionInfo {
    static let version = "2.1.1"
    static let buildNumber = "8"
    static let gitHash = "56dc25a4f7b155b6a62da703cfe58e1533f17e1b"
    static let buildDate = "2026-02-24 20:40:32"
    
    static var displayVersion: String {
        return "\(version).\(buildNumber)"
    }
    
    static var fullVersionInfo: String {
        var info = "AudioWhisper \(version).\(buildNumber)"
        if gitHash != "dev-build" && gitHash != "unknown" && !gitHash.isEmpty {
            let shortHash = String(gitHash.prefix(7))
            info += " • \(shortHash)"
        }
        if !buildDate.isEmpty {
            info += " • \(buildDate)"
        }
        return info
    }
}
