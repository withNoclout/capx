// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CapX",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "capx", targets: ["capx"])
    ],
    targets: [
        .executableTarget(
            name: "capx",
            path: "Sources/capx",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "capxTests",
            dependencies: ["capx"],
            path: "Tests/capxTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
