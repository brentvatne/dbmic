// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "dBMic",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "dBMicCore",
            path: "Sources/dBMicCore"
        ),
        .executableTarget(
            name: "dBMic",
            dependencies: ["dBMicCore"],
            path: "Sources/dBMic",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "dBMicTests",
            dependencies: ["dBMicCore"],
            path: "Tests/dBMicTests"
        )
    ]
)
