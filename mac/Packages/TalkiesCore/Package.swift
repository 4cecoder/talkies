// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TalkiesCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "TalkiesCore", type: .dynamic, targets: ["TalkiesCore"])],
    targets: [.target(name: "TalkiesCore", path: "Sources/TalkiesCore")]
)
