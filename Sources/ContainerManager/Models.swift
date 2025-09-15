import Foundation

/// Basic information about a container.
protocol Named {
    var name: String { get }
}

struct ContainerSummary: Identifiable, Equatable, Named {
    let name: String
    let state: String
    var id: String { name }
}

/// Information about a container image.
struct ImageSummary: Identifiable, Equatable, Named {
    let name: String
    var id: String { name }
}

/// Information about a data volume.
struct VolumeSummary: Identifiable, Equatable, Named {
    let name: String
    var id: String { name }
}

/// Information about a network.
struct NetworkSummary: Identifiable, Equatable, Named {
    let name: String
    var id: String { name }
}
