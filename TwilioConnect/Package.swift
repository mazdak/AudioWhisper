// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TwilioConnect",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TwilioConnect",
            targets: ["TwilioConnect"]
        ),
    ],
    targets: [
        .target(
            name: "TwilioConnect",
            path: ".",
            exclude: ["Resources/Info.plist", "Package.swift"],
            sources: [
                "App",
                "Core",
                "Features",
                "Shared"
            ]
        ),
    ]
)
