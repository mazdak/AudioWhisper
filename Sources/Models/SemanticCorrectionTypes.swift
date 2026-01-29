import Foundation

internal enum SemanticCorrectionMode: String, CaseIterable, Codable, Sendable {
    case off
    case localMLX

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .localMLX: return "Local (MLX)"
        }
    }
}

