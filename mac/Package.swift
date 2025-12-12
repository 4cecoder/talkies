// swift-tools-version: 6.0
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
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        // DISABLED: KokoroSwift has Swift 6.2 compatibility bug in MisakiSwift dependency
        // .package(path: "/tmp/kokoro-ios")
    ],
    targets: [
        .executableTarget(
            name: "Talkies",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                // DISABLED: KokoroSwift has Swift 6.2 compatibility bug
                // .product(name: "KokoroSwift", package: "kokoro-ios")
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-warnings-as-errors"], .when(configuration: .release))
            ]
        ),
    ]
)