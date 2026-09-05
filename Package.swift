// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "helm",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SessionEngine", targets: ["SessionEngine"]),
        .executable(name: "deck", targets: ["deck"]),
    ],
    targets: [
        // The engine: the reusable core. This is the module that stays isolated,
        // so the eventual GUI imports the exact same logic the CLI uses, and the
        // open/closed licensing decision is a property of this target alone.
        .target(name: "SessionEngine"),

        // The CLI front-end. A thin presentation layer over SessionEngine.
        .executableTarget(name: "deck", dependencies: ["SessionEngine"]),
    ]
)
