import ArgumentParser
import Fluent
import FluentPostgresDriver
import FluentMySQLDriver
import FluentSQLiteDriver
import MigrationCore
import Vapor

@main
struct VaporMakeMigration: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "makemigration",
        abstract: "Auto-generate Vapor migration files by comparing models with database schema",
        version: "1.0.0"
    )

    @ArgumentParser.Option(name: .shortAndLong, help: "Path to your Vapor project")
    var projectPath: String = "."

    @ArgumentParser.Option(
        name: .shortAndLong,
        help: "Database connection string (e.g., postgres://user:pass@localhost/db)")
    var database: String

    @ArgumentParser.Option(name: .shortAndLong, help: "Migration name")
    var name: String = "AutoMigration"

    @ArgumentParser.Option(name: .long, help: "Path to migrations directory")
    var migrationsPath: String = "./Sources/App/Migrations"

    @ArgumentParser.Flag(name: .long, help: "Preview changes without creating migration file")
    var preview: Bool = false

    @ArgumentParser.Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    init() {}

    func run() async throws {
        print("Vapor Migration Generator")
        print("========================================")

        // Parse database URL
        guard let dbConfig = try parseDatabase(database) else {
            throw ValidationError("Invalid database URL")
        }

        if verbose {
            print("Connecting to database: \(dbConfig.type)")
        }

        // Create Vapor application
        var env = try Environment.detect()
        env.arguments = []

        let app = try await Application.make(env)
        defer { Task { try? await app.asyncShutdown() } }

        // Configure database
        try await configureDatabase(app, config: dbConfig)

        // Introspect current database schema
        print("\nReading current database schema...")
        let dbIntrospector = DatabaseIntrospector(database: app.db)
        let currentSchema = try await dbIntrospector.introspect()

        if verbose {
            print("   Found \(currentSchema.tables.count) tables")
        }

        // For now, we'll need users to provide their models
        // In a real implementation, you'd scan the project and load models
        print("\nNote: Model scanning requires runtime integration")
        print("   Please ensure your models are registered with Fluent")

        // Create a mock desired schema for demonstration
        // In production, this would come from ModelIntrospector
        let desiredSchema = try loadModelsSchema(app)

        // Compare schemas
        print("\nComparing schemas...")
        let comparator = SchemaComparator()
        let diff = comparator.compare(current: currentSchema, desired: desiredSchema)

        if diff.isEmpty {
            print("No changes detected - database is in sync with models")
            return
        }

        // Display changes
        print("\nDetected changes:")
        for (index, change) in diff.changes.enumerated() {
            print("   \(index + 1). \(change.description)")
        }

        if preview {
            print("\nPreview mode - no files will be created")
            let generator = MigrationGenerator()
            let code = generator.generate(diff: diff, name: name)
            print("\n========================================")
            print(code)
            print("========================================")
            return
        }

        // Generate migration file
        print("\nGenerating migration file...")
        let generator = MigrationGenerator()
        let migrationCode = generator.generate(diff: diff, name: name)

        // Write to file
        let writer = MigrationFileWriter(basePath: migrationsPath)
        try writer.write(migrationCode: migrationCode, name: name)

        print("Migration file created in \(migrationsPath)")
        print("\nDon't forget to:")
        print("   1. Review the generated migration file")
        print("   2. Register it in your configure.swift")
        print("   3. Run 'vapor run migrate' to apply it")
    }

    private func parseDatabase(_ url: String) throws -> DatabaseConfig? {
        guard let components = URLComponents(string: url) else {
            return nil
        }

        let scheme = components.scheme ?? ""
        let host = components.host ?? "localhost"
        let port = components.port
        let username = components.user
        let password = components.password
        let database = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let type: DatabaseType
        switch scheme {
        case "postgres", "postgresql":
            type = .postgres
        case "mysql":
            type = .mysql
        case "sqlite":
            type = .sqlite
        default:
            return nil
        }

        return DatabaseConfig(
            type: type,
            host: host,
            port: port,
            username: username,
            password: password,
            database: database
        )
    }

    private func configureDatabase(_ app: Application, config: DatabaseConfig) async throws {
        switch config.type {
        case .postgres:
            guard let username = config.username,
                let password = config.password
            else {
                throw ValidationError("PostgreSQL requires username and password")
            }

            let postgresConfig = SQLPostgresConfiguration(
                hostname: config.host,
                port: config.port ?? 5432,
                username: username,
                password: password,
                database: config.database,
                tls: .disable
            )
            app.databases.use(.postgres(configuration: postgresConfig), as: .psql)

        case .mysql:
            guard let username = config.username,
                let password = config.password
            else {
                throw ValidationError("MySQL requires username and password")
            }

            let mysqlConfig = MySQLConfiguration(
                hostname: config.host,
                port: config.port ?? 3306,
                username: username,
                password: password,
                database: config.database,
                tlsConfiguration: .none
            )
            app.databases.use(.mysql(configuration: mysqlConfig), as: .mysql)

        case .sqlite:
            app.databases.use(.sqlite(.file(config.database)), as: .sqlite)
        }
    }

    private func loadModelsSchema(_ app: Application) throws -> MigrationCore.DatabaseSchema {
        // In a real implementation, this would:
        // 1. Scan the project for Model types
        // 2. Use ModelIntrospector to build schema
        // 3. Return the desired schema

        // For now, return empty schema
        // Users will need to integrate this with their app
        return MigrationCore.DatabaseSchema(tables: [])
    }
}

struct DatabaseConfig {
    let type: DatabaseType
    let host: String
    let port: Int?
    let username: String?
    let password: String?
    let database: String
}

enum DatabaseType {
    case postgres
    case mysql
    case sqlite
}
