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
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "2.30.6"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.30.6"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.1.6"),
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
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Transformers", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Sources/TalkiesInference"
        ),
        .executableTarget(
            name: "Talkies",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                "TalkiesCore",
                "TalkiesInference",
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
            name: "TalkiesInferenceTests",
            dependencies: ["TalkiesInference"],
            path: "Tests/TalkiesInferenceTests"
        ),
    ]
)
