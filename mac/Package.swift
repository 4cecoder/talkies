// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Talkies",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "Talkies",
            targets: ["Talkies"]
        ),
        .library(
            name: "TalkiesCore",
            targets: ["TalkiesCore"]
        ),
        .library(
            name: "TalkiesInference",
            targets: ["TalkiesInference"]
        ),
        .library(
            name: "TalkiesAudio",
            targets: ["TalkiesAudio"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/mattt/llama.swift", exact: "2.10549.0"),
        // DISABLED: KokoroSwift has Swift 6.2 compatibility bug in MisakiSwift dependency
        // .package(path: "/tmp/kokoro-ios")
    ],
    targets: [
        .target(
            name: "TalkiesCore",
            path: "Sources/TalkiesCore"
        ),
        .target(
            name: "TalkiesInference",
            dependencies: [
                "TalkiesCore",
                .product(name: "LlamaSwift", package: "llama.swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/TalkiesInference"
        ),
        .target(
            name: "TalkiesAudio",
            path: "Sources/TalkiesAudio"
        ),
        .executableTarget(
            name: "Talkies",
            dependencies: [
                "TalkiesCore",
                "TalkiesInference",
                "TalkiesAudio",
                // DISABLED: KokoroSwift has Swift 6.2 compatibility bug
                // .product(name: "KokoroSwift", package: "kokoro-ios")
            ],
            path: "Sources/Talkies",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),
        .testTarget(
            name: "TalkiesCoreTests",
            dependencies: ["TalkiesCore"],
            path: "Tests/TalkiesCoreTests"
        ),
        .testTarget(
            name: "TalkiesAudioTests",
            dependencies: ["TalkiesAudio"],
            path: "Tests/TalkiesAudioTests"
        ),
        .testTarget(
            name: "TalkiesInferenceTests",
            dependencies: [
                "TalkiesInference",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Tests/TalkiesInferenceTests"
        ),
    ]
)
