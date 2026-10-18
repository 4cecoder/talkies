// swift-tools-version: 6.3
import PackageDescription

// Agent connectors change whenever cmux, herdr, ACP, or Hindsight change, so they live
// beside inference on the high-volatility side. The app depends only on the
// TalkiesCore AgentConnector contract; this package implements it.
let package = Package(
    name: "TalkiesConnectors",
    platforms: [.macOS(.v15)],
    products: [.library(name: "TalkiesConnectors", targets: ["TalkiesConnectors"])],
    dependencies: [.package(path: "../TalkiesCore")],
    targets: [
        .target(
            name: "TalkiesConnectors",
            dependencies: [.product(name: "TalkiesCore", package: "TalkiesCore")],
            path: "Sources/TalkiesConnectors"
        ),
    ]
)
