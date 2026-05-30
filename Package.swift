// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "macMender",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacMenderMenuBarEngine", targets: ["MacMenderMenuBarEngine"]),
        .executable(name: "MacMenderMenuBarItemService", targets: ["MacMenderMenuBarItemService"]),
        .executable(name: "macMender", targets: ["macMender"])
    ],
    targets: [
        .target(
            name: "MacMenderMenuBarEngine",
            dependencies: []
        ),
        .executableTarget(
            name: "MacMenderMenuBarItemService",
            dependencies: []
        ),
        .executableTarget(
            name: "macMender",
            dependencies: [
                "MacMenderMenuBarEngine",
                "MultitouchSupport"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"]),
                .linkedFramework("MultitouchSupport")
            ]
        ),
        .systemLibrary(
            name: "MultitouchSupport",
            path: "Sources/MultitouchSupport"
        ),
        .testTarget(
            name: "macMenderTests",
            dependencies: [
                "macMender",
                "MacMenderMenuBarEngine"
            ]
        )
    ]
)
