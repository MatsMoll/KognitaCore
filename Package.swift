// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KognitaCore",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "KognitaCore",
            targets: ["KognitaCore"]),
        .library(
            name: "KognitaCoreTestable",
            targets: ["KognitaCoreTestable"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(name: "Vapor", url: "https://github.com/vapor/vapor.git", from: "3.3.3"),

        // 👤 Authentication and Authorization layer for Fluent.
        .package(name: "Auth", url: "https://github.com/vapor/auth.git", from: "2.0.0"),

        // 🐘 Non-blocking, event-driven Swift client for PostgreSQL.
        .package(name: "FluentPostgreSQL", url: "https://github.com/vapor/fluent-postgres-driver.git", from: "1.0.0"),

        // SwiftSoup for HTML sanitizing
        .package(name: "SwiftSoup", url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "KognitaCore",
            dependencies: [
                .product(name: "Authentication", package: "Auth"),
                .product(name: "FluentPostgreSQL", package: "FluentPostgreSQL"),
                .product(name: "Vapor", package: "Vapor"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
        .target(
            name: "KognitaCoreTestable",
            dependencies: [
                .target(name: "KognitaCore")
            ]
        ),
        .testTarget(
            name: "KognitaCoreTests",
            dependencies: [
                .target(name: "KognitaCoreTestable")
            ]
        ),
    ]
)
