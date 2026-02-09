// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicMeter",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MicMeterCore",
            path: "Sources/MicMeterCore"
        ),
        .executableTarget(
            name: "MicMeter",
            dependencies: ["MicMeterCore"],
            path: "Sources/MicMeter",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "MicMeterTests",
            dependencies: ["MicMeterCore"],
            path: "Tests/MicMeterTests"
        )
    ]
)
