// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AudioWhisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.13.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioWhisper",
            dependencies: ["Alamofire", "HotKey", "WhisperKit"],
            path: "Sources",
            exclude: ["__pycache__", "VersionInfo.swift.template"],
            resources: [
                .process("Assets.xcassets"),
                .copy("parakeet_transcribe_pcm.py")
            ]
        ),
        .testTarget(
            name: "AudioWhisperTests",
            dependencies: ["AudioWhisper"],
            path: "Tests",
            exclude: ["README.md", "test_parakeet_transcribe.py"]
        )
    ]
)