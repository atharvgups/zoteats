// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ZotEatsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ZotEatsKit", targets: ["ZotEatsKit"])
    ],
    targets: [
        .target(
            name: "ZotEatsKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ZotEatsKitTests",
            dependencies: ["ZotEatsKit"],
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
