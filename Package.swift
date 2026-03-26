// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "N42BugReporter",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "BugReporter",
            targets: ["BugReporter"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/devicekit/DeviceKit", exact: "5.8.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift", exact: "6.10.2"),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger", exact: "7.1.5"),
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", exact: "2.6.0"),
    ],
    targets: [
        .target(
            name: "BugReporter",
            dependencies: [
                "DeviceKit",
                .product(name: "RxSwift", package: "RxSwift"),
                "XCGLogger",
                .product(name: "ZipArchive", package: "ZipArchive"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
