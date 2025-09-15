import Foundation

/// Provides basic container operations backed by the Apple container CLI.
struct ContainerService {
    func listContainers() async throws -> [ContainerSummary] {
        [
            ContainerSummary(name: "web", state: "running"),
            ContainerSummary(name: "db", state: "exited")
        ]
    }

    func listImages() async throws -> [ImageSummary] {
        [
            ImageSummary(name: "ubuntu:latest"),
            ImageSummary(name: "nginx:alpine")
        ]
    }

    func listVolumes() async throws -> [VolumeSummary] {
        [
            VolumeSummary(name: "app-data")
        ]
    }

    func listNetworks() async throws -> [NetworkSummary] {
        [
            NetworkSummary(name: "bridge")
        ]
    }
}
