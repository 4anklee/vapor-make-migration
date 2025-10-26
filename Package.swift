// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "vapor-make-migration",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "vapor-make-migration",
            targets: ["VaporMakeMigration"]
        ),
        .library(
            name: "MigrationCore",
            targets: ["MigrationCore"]
        ),
        .library(
            name: "VaporMakeCommand",
            targets: ["VaporMakeCommand"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.28.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.4.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "VaporMakeMigration",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "MigrationCore",
            ]
        ),
        .target(
            name: "MigrationCore",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        ),
        .target(
            name: "VaporMakeCommand",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                "MigrationCore",
            ]
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "MigrationCore",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
            ]
        ),
    ]
)
