import Vapor
import Fluent
import MigrationCore

/// Vapor command for generating migrations
///
/// To use this in your Vapor app, add to configure.swift:
/// ```
/// app.commands.use(MakeMigrationCommand(), as: "makemigration")
/// ```
///
/// Then run:
/// ```
/// vapor run makemigration --preview
/// vapor run makemigration --name AddUserFields
/// ```
public struct MakeMigrationCommand: AsyncCommand {
    public struct Signature: CommandSignature {
        @Option(name: "name", short: "n", help: "Migration name")
        public var name: String?

        @Flag(name: "preview", help: "Preview changes without creating files")
        public var preview: Bool

        @Option(name: "path", help: "Path to migrations directory")
        public var path: String?

        public init() {}
    }

    public var help: String {
        "Generate migration by comparing Fluent models with current database schema"
    }

    public init() {}

    public func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application

        context.console.info("Vapor Make Migration")
        context.console.info("========================================")

        // 1. Introspect current database schema
        context.console.info("Reading current database schema...")
        let dbIntrospector = DatabaseIntrospector(database: app.db)
        let currentSchema = try await dbIntrospector.introspect()

        context.console.info("Found \(currentSchema.tables.count) tables in database")

        // 2. Get desired schema from models
        // Note: You need to register your models here or implement a model registry
        context.console.warning("Model introspection requires manual model registration")
        context.console.info("Please implement a model registry or manually specify models")

        // Example of how to use with models:
        let modelIntrospector = ModelIntrospector()
        let desiredSchema = try modelIntrospector.introspect(models: getRegisteredModels(app))

        context.console.info("Found \(desiredSchema.tables.count) model(s)")

        // 3. Compare schemas
        context.console.info("\nComparing schemas...")
        let comparator = SchemaComparator()
        let diff = comparator.compare(current: currentSchema, desired: desiredSchema)

        if diff.isEmpty {
            context.console.success("No changes detected - database is in sync!")
            return
        }

        // 4. Display changes
        context.console.info("\nDetected changes:")
        for (index, change) in diff.changes.enumerated() {
            context.console.print("  \(index + 1). \(change.description)")
        }

        // 5. Generate migration code
        let migrationName = signature.name ?? "AutoMigration"
        let generator = MigrationGenerator()
        let migrationCode = generator.generate(diff: diff, name: migrationName)

        if signature.preview {
            context.console.info("\nPreview mode - no files will be created")
            context.console.print("\n========================================")
            context.console.print(migrationCode)
            context.console.print("========================================")
        } else {
            // Write to file
            let migrationsPath = signature.path ?? (app.directory.workingDirectory + "Sources/App/Migrations")
            let writer = MigrationFileWriter(basePath: migrationsPath)
            try writer.write(migrationCode: migrationCode, name: migrationName)

            context.console.success("Migration file created in \(migrationsPath)")
            context.console.info("\nNext steps:")
            context.console.info("  1. Review the generated migration file")
            context.console.info("  2. Register it in configure.swift")
            context.console.info("  3. Run 'vapor run migrate' to apply it")
        }
    }

    /// Override this method to provide your models
    ///
    /// Example:
    /// ```
    /// private func getRegisteredModels(_ app: Application) -> [any Model.Type] {
    ///     return [
    ///         User.self,
    ///         Product.self,
    ///         Order.self
    ///     ]
    /// }
    /// ```
    private func getRegisteredModels(_ app: Application) -> [any Model.Type] {
        // Return empty array by default
        // Users should override this or implement a model registry
        return []
    }
}

// MARK: - Model Registry Protocol

/// Protocol for applications to implement for automatic model discovery
public protocol ModelRegistry {
    /// All models that should be considered for migration generation
    static var models: [any Model.Type] { get }
}

// MARK: - Extended Command with Model Registry

/// Extended command that uses a ModelRegistry
public struct MakeMigrationCommandWithRegistry<Registry: ModelRegistry>: AsyncCommand {
    public struct Signature: CommandSignature {
        @Option(name: "name", short: "n", help: "Migration name")
        public var name: String?

        @Flag(name: "preview", help: "Preview changes without creating files")
        public var preview: Bool

        @Option(name: "path", help: "Path to migrations directory")
        public var path: String?

        public init() {}
    }

    public var help: String {
        "Generate migration by comparing Fluent models with current database schema"
    }

    public init() {}

    public func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application

        context.console.info("Vapor Make Migration")
        context.console.info("========================================")

        // 1. Introspect current database schema
        context.console.info("Reading current database schema...")
        let dbIntrospector = DatabaseIntrospector(database: app.db)
        let currentSchema = try await dbIntrospector.introspect()

        context.console.info("Found \(currentSchema.tables.count) tables in database")

        // 2. Get desired schema from models using the registry
        context.console.info("Analyzing models from registry...")
        let modelIntrospector = ModelIntrospector()
        let desiredSchema = try modelIntrospector.introspect(models: Registry.models)

        context.console.info("Found \(desiredSchema.tables.count) model(s)")

        // 3. Compare schemas
        context.console.info("\nComparing schemas...")
        let comparator = SchemaComparator()
        let diff = comparator.compare(current: currentSchema, desired: desiredSchema)

        if diff.isEmpty {
            context.console.success("No changes detected - database is in sync!")
            return
        }

        // 4. Display changes
        context.console.info("\nDetected changes:")
        for (index, change) in diff.changes.enumerated() {
            context.console.print("  \(index + 1). \(change.description)")
        }

        // 5. Generate migration code
        let migrationName = signature.name ?? "AutoMigration"
        let generator = MigrationGenerator()
        let migrationCode = generator.generate(diff: diff, name: migrationName)

        if signature.preview {
            context.console.info("\nPreview mode - no files will be created")
            context.console.print("\n========================================")
            context.console.print(migrationCode)
            context.console.print("========================================")
        } else {
            // Write to file
            let migrationsPath = signature.path ?? (app.directory.workingDirectory + "Sources/App/Migrations")
            let writer = MigrationFileWriter(basePath: migrationsPath)
            try writer.write(migrationCode: migrationCode, name: migrationName)

            context.console.success("Migration file created in \(migrationsPath)")
            context.console.info("\nNext steps:")
            context.console.info("  1. Review the generated migration file")
            context.console.info("  2. Register it in configure.swift")
            context.console.info("  3. Run 'vapor run migrate' to apply it")
        }
    }
}
