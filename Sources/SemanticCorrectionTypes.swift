import Foundation

enum SemanticCorrectionMode: String, CaseIterable, Codable, Sendable {
    case off
    case localMLX
    case cloud
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .localMLX: return "Local (MLX)"
        case .cloud: return "Cloud"
        }
    }
}

