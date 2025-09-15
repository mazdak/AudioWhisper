#if os(macOS)
import SwiftUI

@MainActor
struct ContainerMenuView: View {
    @State private var containers: [ContainerSummary] = []
    @State private var images: [ImageSummary] = []
    @State private var volumes: [VolumeSummary] = []
    @State private var networks: [NetworkSummary] = []
    private let service = ContainerService()

    var body: some View {
        VStack(alignment: .leading) {
            resourceSection("Containers", items: containers)
            Divider()
            resourceSection("Images", items: images)
            Divider()
            resourceSection("Volumes", items: volumes)
            Divider()
            resourceSection("Networks", items: networks)
            Divider()
            Button("Refresh") { Task { await refresh() } }
        }
        .padding()
        .task { await refresh() }
    }

    private func resourceSection<T: Named & Identifiable>(_ title: String, items: [T]) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if items.isEmpty {
                Text("None").foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Text(item.name)
                }
            }
        }
    }

    private func refresh() async {
        containers = (try? await service.listContainers()) ?? []
        images = (try? await service.listImages()) ?? []
        volumes = (try? await service.listVolumes()) ?? []
        networks = (try? await service.listNetworks()) ?? []
    }
}
#endif
