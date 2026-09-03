// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "Aurora-Shell",
    products: [
        .library(
            name: "Aurora-Shell",
            targets: ["Aurora-Shell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "7.1.2"),
    ],
    targets: [
        .target(
            name: "Aurora-Shell",
            dependencies: ["SwiftTerm"]),
        .testTarget(
            name: "AuroraShellTests",
            dependencies: ["SwiftTerm"]),
    ]
)
