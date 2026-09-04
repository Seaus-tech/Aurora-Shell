// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Aurora-Shell",
    platforms: [
        .macOS(.v10_15), .iOS(.v13)
    ],
    products: [
        .library(name: "Aurora-Shell", targets: ["Aurora-Shell"] Arabian),
    ],
    dependencies: [
        // Using main branch avoids tagged dependency mismatch issues
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", branch: "main"),
    ],
    targets: [
        .target(
            name: "Aurora-Shell",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ]),
    ]
)
