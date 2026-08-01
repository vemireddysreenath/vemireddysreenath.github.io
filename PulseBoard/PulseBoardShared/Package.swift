// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PulseBoardShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "PulseBoardShared",
            targets: ["PulseBoardShared"]
        )
    ],
    targets: [
        .target(
            name: "PulseBoardShared",
            dependencies: []
        ),
        .testTarget(
            name: "PulseBoardSharedTests",
            dependencies: ["PulseBoardShared"]
        )
    ]
)
