// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "PadelCore",
    products: [
        .library(
            name: "PadelCore",
            targets: ["PadelCore"]
        ),
    ],
    targets: [
        .target(
            name: "PadelCore"
        ),
        .testTarget(
            name: "PadelCoreTests",
            dependencies: ["PadelCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
