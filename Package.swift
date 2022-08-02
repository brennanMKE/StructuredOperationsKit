// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StructuredOperationsKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "StructuredOperationsKit",
            targets: ["StructuredOperationsKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/brennanMKE/AsyncChannelKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "StructuredOperationsKit",
            dependencies: ["AsyncChannelKit"]),
        .testTarget(
            name: "StructuredOperationsKitTests",
            dependencies: ["StructuredOperationsKit"]),
    ]
)
