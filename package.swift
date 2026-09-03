// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Aurora-Shell",
    platforms: [
        .macOS(.v10_15), .iOS(.v13)
    ],
    products: [
        .library(
            name: "Aurora-Shell",
            targets: ["Aurora-Shell"]),
    ],
    dependencies: [
        // Point directly to the main branch since version 7.1.2 does not exist
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", branch: "main"),
    ],
    targets: [
        .target(
            name: "Aurora-Shell",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]),
        .testTarget(
            name: "AuroraShellTests",
            dependencies: [
                "Aurora-Shell",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]),
    ]
)
