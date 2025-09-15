import XCTest
@testable import ContainerManager

final class ContainerServiceTests: XCTestCase {
    func testListContainersReturnsSampleData() async throws {
        let service = ContainerService()
        let containers = try await service.listContainers()
        XCTAssertEqual(containers.map { $0.name }, ["web", "db"])
    }

    func testListImagesReturnsSampleData() async throws {
        let service = ContainerService()
        let images = try await service.listImages()
        XCTAssertEqual(images.map { $0.name }, ["ubuntu:latest", "nginx:alpine"])
    }

    func testListVolumesReturnsSampleData() async throws {
        let service = ContainerService()
        let volumes = try await service.listVolumes()
        XCTAssertEqual(volumes.map { $0.name }, ["app-data"])
    }

    func testListNetworksReturnsSampleData() async throws {
        let service = ContainerService()
        let networks = try await service.listNetworks()
        XCTAssertEqual(networks.map { $0.name }, ["bridge"])
    }
}
