// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiniRxSwift",
    products: [
        .library(name: "MiniRxSwift", targets: ["MiniRxSwift"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MiniRxSwift",
            dependencies: []),
        .testTarget(
            name: "MiniRxSwiftTests",
            dependencies: ["MiniRxSwift"]),
    ]
)
