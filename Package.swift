// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KognitaCore",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KognitaCore",
            targets: ["KognitaCore"]),
    ],
    dependencies: [
        // 👤 Authentication and Authorization layer for Fluent.
        .package(url: "https://github.com/vapor/auth.git", from: "2.0.0"),

        // 🐘 Non-blocking, event-driven Swift client for PostgreSQL.
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),

        .package(url: "https://github.com/MihaelIsaev/SwifQL.git", from: "0.20.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "KognitaCore",
            dependencies: [
                "Authentication",
                "FluentPostgreSQL",
                "SwifQL",
                "SwifQLVapor"
            ]
        ),
        .testTarget(
            name: "KognitaCoreTests",
            dependencies: ["KognitaCore"]),
    ]
)
