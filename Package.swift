// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

var dependencies: [Package.Dependency] = [
    // 💧 A server-side Swift web framework.
    .package(name: "vapor", url: "https://github.com/vapor/vapor.git", from: "4.29.0"),

    // 🐘 Non-blocking, event-driven Swift client for PostgreSQL.
    .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.1.0"),
    
    .package(url: "https://github.com/vapor/sql-kit", from: "3.7.0"),

    .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),

    // SwiftSoup for HTML sanitizing
    .package(name: "SwiftSoup", url: "https://github.com/scinfu/SwiftSoup.git", from: "2.3.0"),
]

switch ProcessInfo.processInfo.environment["BUILD_TYPE"] {
case "LOCAL":
    dependencies.append(contentsOf: [
            .package(path: "../KognitaModels"),
        ]
    )
case "DEV":
    dependencies.append(contentsOf: [
            .package(name: "KognitaModels", url: "https://Kognita:dyjdov-bupgev-goffY8@github.com/MatsMoll/KognitaModels", .branch("develop")),
        ]
    )
default:
    dependencies.append(contentsOf: [
            .package(name: "KognitaModels", url: "https://Kognita:dyjdov-bupgev-goffY8@github.com/MatsMoll/KognitaModels", from: "1.0.0"),
        ]
    )
}

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
    dependencies: dependencies,
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "KognitaCore",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "KognitaModels", package: "KognitaModels"),
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
                .target(name: "KognitaCoreTestable"),
                .product(name: "XCTVapor", package: "vapor")
            ]
        ),
    ]
)
