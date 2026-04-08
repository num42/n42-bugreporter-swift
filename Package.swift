// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "N42BugReporter",
    platforms: [
        .iOS("15.5")
    ],
    products: [
        .library(
            name: "BugReporter",
            targets: ["BugReporter"]
        ),
    ],
    targets: [
        .target(
            name: "BugReporter"
        ),
        .testTarget(
            name: "BugReporterTests",
            dependencies: [
                "BugReporter",
            ]
        ),
    ]
)
