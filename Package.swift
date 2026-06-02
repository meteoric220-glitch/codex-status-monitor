// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexStatusMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexStatusMonitor", targets: ["CodexStatusMonitor"]),
        .library(name: "CodexStatusMonitorCore", targets: ["CodexStatusMonitorCore"])
    ],
    targets: [
        .target(
            name: "CodexStatusMonitorCore"
        ),
        .executableTarget(
            name: "CodexStatusMonitor",
            dependencies: ["CodexStatusMonitorCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "CodexStatusMonitorCoreChecks",
            dependencies: ["CodexStatusMonitorCore"]
        )
    ]
)
