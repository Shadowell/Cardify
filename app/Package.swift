// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Cardify",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CardifyCore", targets: ["CardifyCore"]),
        .executable(name: "CardifyApp", targets: ["CardifyApp"]),
        .executable(name: "CardifySchemaCheck", targets: ["CardifySchemaCheck"])
    ],
    targets: [
        .target(name: "CardifyCore"),
        .executableTarget(name: "CardifyApp", dependencies: ["CardifyCore"]),
        .executableTarget(name: "CardifySchemaCheck", dependencies: ["CardifyCore"])
    ]
)
