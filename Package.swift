// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ContainerManager",
    products: [
        .executable(name: "ContainerManager", targets: ["ContainerManager"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ContainerManager",
            dependencies: []),
        .testTarget(
            name: "ContainerManagerTests",
            dependencies: ["ContainerManager"])
    ]
)
