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
    dependencies: [
        .package(url: "https://github.com/DaveWoodCom/XCGLogger", exact: "7.1.5"),
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.6.0"),
    ],
    targets: [
        .target(
            name: "BugReporter",
            dependencies: [
                "XCGLogger",
                .product(name: "ZipArchive", package: "ZipArchive"),
            ]
        ),
        .testTarget(
            name: "BugReporterTests",
            dependencies: [
                "BugReporter",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
