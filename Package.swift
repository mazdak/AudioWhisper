// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AudioWhisper",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioWhisper",
            dependencies: ["Alamofire", "HotKey", "WhisperKit"],
            path: "Sources",
            exclude: ["VersionInfo.swift.template"],
            resources: [
                .process("Assets.xcassets"),
                .copy("parakeet_transcribe_pcm.py"),
                .copy("mlx_semantic_correct.py"),
                .copy("verify_parakeet.py"),
                .copy("verify_mlx.py"),
                // Bundle additional resources like uv binary and lock files
                .copy("Resources")
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
