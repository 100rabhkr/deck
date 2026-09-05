// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "helm",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SessionEngine", targets: ["SessionEngine"]),
        .executable(name: "deck", targets: ["deck"]),
        .executable(name: "HelmApp", targets: ["HelmApp"]),
    ],
    dependencies: [
        // Pinned, prebuilt libghostty terminal surface (proven in the Phase 0 spike).
        .package(url: "https://github.com/arach/Termini.git", exact: "0.1.2"),
    ],
    targets: [
        // The engine: the reusable core. This is the module that stays isolated,
        // so the GUI imports the exact same logic the CLI uses, and the
        // open/closed licensing decision is a property of this target alone.
        .target(name: "SessionEngine"),

        // The CLI front-end. A thin presentation layer over SessionEngine.
        .executableTarget(name: "deck", dependencies: ["SessionEngine"]),

        // The macOS app: home screen (SessionEngine) + libghostty terminal tabs.
        .executableTarget(
            name: "HelmApp",
            dependencies: [
                "SessionEngine",
                .product(name: "Termini", package: "Termini"),
            ]
        ),
    ]
)
