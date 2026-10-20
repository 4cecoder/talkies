// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TalkiesMonterey",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "TalkiesMonterey", targets: ["TalkiesMonterey"])],
    targets: [
        .executableTarget(
            name: "TalkiesMonterey",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
