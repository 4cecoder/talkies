// swift-tools-version: 5.10
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
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        // DISABLED: KokoroSwift has Swift 6.2 compatibility bug in MisakiSwift dependency
        // .package(path: "/tmp/kokoro-ios")
    ],
    targets: [
        // Core library with business logic (testable)
        .target(
            name: "TalkiesCore",
            dependencies: [],
            path: "Sources/TalkiesCore"
        ),
        // Main executable with UI and WhisperKit
        .executableTarget(
            name: "Talkies",
            dependencies: [
                "TalkiesCore",
                .product(name: "WhisperKit", package: "WhisperKit"),
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
    ]
)