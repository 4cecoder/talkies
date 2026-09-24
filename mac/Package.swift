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
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        // DISABLED: KokoroSwift has Swift 6.2 compatibility bug in MisakiSwift dependency
        // .package(path: "/tmp/kokoro-ios")
    ],
    targets: [
        .target(
            name: "TalkiesCore",
            path: "Sources/TalkiesCore"
        ),
        .executableTarget(
            name: "Talkies",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                "TalkiesCore",
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
