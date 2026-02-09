// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicMeter",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MicMeter",
            path: "Sources/MicMeter",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
