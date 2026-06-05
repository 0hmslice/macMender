// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "macMender",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "macMender", targets: ["macMender"])
    ],
    targets: [
        .executableTarget(
            name: "macMender",
            dependencies: [
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
        )
    ]
)
