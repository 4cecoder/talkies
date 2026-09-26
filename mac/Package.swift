// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Talkies",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Talkies", targets: ["Talkies"]),
        .library(name: "TalkiesAudio", targets: ["TalkiesAudio"]),
        .library(name: "TalkiesAccessibility", targets: ["TalkiesAccessibility"]),
    ],
    dependencies: [
        .package(path: "Packages/TalkiesCore"),
        .package(path: "Packages/TalkiesInference"),
        // DISABLED: KokoroSwift has Swift 6.2 compatibility bug in MisakiSwift dependency
        // .package(path: "/tmp/kokoro-ios")
    ],
    targets: [
        .target(name: "TalkiesAudio", path: "Sources/TalkiesAudio"),
        .target(
            name: "TalkiesAccessibility",
            dependencies: [.product(name: "TalkiesCore", package: "TalkiesCore")],
            path: "Sources/TalkiesAccessibility"
        ),
        .executableTarget(
            name: "Talkies",
            dependencies: [
                .product(name: "TalkiesCore", package: "TalkiesCore"),
                .product(name: "TalkiesInference", package: "TalkiesInference"),
                "TalkiesAudio",
                "TalkiesAccessibility",
                // DISABLED: KokoroSwift has Swift 6.2 compatibility bug
                // .product(name: "KokoroSwift", package: "kokoro-ios")
            ],
            path: "Sources/Talkies",
            swiftSettings: [.unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))]
        ),
        .testTarget(name: "TalkiesAudioTests", dependencies: ["TalkiesAudio"], path: "Tests/TalkiesAudioTests"),
        .testTarget(
            name: "TalkiesCoreTests",
            dependencies: [.product(name: "TalkiesCore", package: "TalkiesCore")],
            path: "Tests/TalkiesCoreTests"
        ),
        .testTarget(
            name: "TalkiesAccessibilityTests",
            dependencies: ["TalkiesAccessibility"],
            path: "Tests/TalkiesAccessibilityTests"
        ),
        .testTarget(
            name: "TalkiesInferenceTests",
            dependencies: [
                .product(name: "TalkiesInference", package: "TalkiesInference"),
                "TalkiesAccessibility",
            ],
            path: "Tests/TalkiesInferenceTests"
        ),
    ]
)
