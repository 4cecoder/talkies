// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TalkiesInference",
    platforms: [.macOS(.v15)],
    products: [.library(name: "TalkiesInference", type: .dynamic, targets: ["TalkiesInference"])],
    dependencies: [
        .package(path: "../TalkiesCore"),
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "1.1.0"),
        .package(url: "https://github.com/mattt/llama.swift", exact: "2.10549.0"),
    ],
    targets: [
        .target(
            name: "TalkiesInference",
            dependencies: [
                .product(name: "TalkiesCore", package: "TalkiesCore"),
                .product(name: "LlamaSwift", package: "llama.swift"),
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/TalkiesInference"
        ),
    ]
)
