// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PadelCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PadelCore",
            targets: ["PadelCore"]
        ),
    ],
    targets: [
        .target(
            name: "PadelCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PadelCoreTests",
            dependencies: ["PadelCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
