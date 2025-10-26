import Fluent
import MigrationCore
import Vapor

// Example of how to integrate vapor-make-migration into your Vapor application

/// Example User model
final class User: Model {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "email")
    var email: String

    @Field(key: "age")
    var age: Int?

    @Timestamp(key: "createdAt", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, email: String, age: Int? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.age = age
    }
}

/// Example Product model
final class Product: Model {
    static let schema = "products"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "price")
    var price: Double

    @Field(key: "description")
    var description: String?

    @Field(key: "inStock")
    var inStock: Bool

    init() {}

    init(
        id: UUID? = nil, name: String, price: Double, description: String? = nil,
        inStock: Bool = true
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.description = description
        self.inStock = inStock
    }
}

/// Command to generate migrations
struct GenerateMigrationCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "name", short: "n", help: "Migration name")
        var name: String?

        @Flag(name: "preview", help: "Preview changes without creating files")
        var preview: Bool
    }

    var help: String {
        "Generate migration by comparing models with database"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application

        // 1. Introspect current database schema
        context.console.print("Reading current database schema...")
        let dbIntrospector = DatabaseIntrospector(database: app.db)
        let currentSchema = try await dbIntrospector.introspect()

        context.console.print("Found \(currentSchema.tables.count) tables in database")

        // 2. Introspect models to get desired schema
        context.console.print("Analyzing models...")
        let modelIntrospector = ModelIntrospector()
        let desiredSchema = try modelIntrospector.introspect(models: [
            User.self,
            Product.self,
                // Add all your models here
        ])

        context.console.print("Found \(desiredSchema.tables.count) models")

        // 3. Compare schemas
        context.console.print("Comparing schemas...")
        let comparator = SchemaComparator()
        let diff = comparator.compare(current: currentSchema, desired: desiredSchema)

        if diff.isEmpty {
            context.console.success("No changes detected - database is in sync!")
            return
        }

        // 4. Display changes
        context.console.print("\nDetected changes:")
        for (index, change) in diff.changes.enumerated() {
            context.console.print("  \(index + 1). \(change.description)")
        }

        // 5. Generate migration code
        let migrationName = signature.name ?? "AutoMigration"
        let generator = MigrationGenerator()
        let migrationCode = generator.generate(diff: diff, name: migrationName)

        if signature.preview {
            context.console.print("\nPreview mode - no files will be created")
            context.console.print("\n========================================")
            context.console.print(migrationCode)
            context.console.print("========================================")
        } else {
            // Write to file
            let migrationsPath = app.directory.workingDirectory + "Sources/App/Migrations"
            let writer = MigrationFileWriter(basePath: migrationsPath)
            try writer.write(migrationCode: migrationCode, name: migrationName)

            context.console.success("Migration file created in \(migrationsPath)")
            context.console.print("\nNext steps:")
            context.console.print("  1. Review the generated migration file")
            context.console.print("  2. Register it in configure.swift")
            context.console.print("  3. Run 'vapor run migrate' to apply it")
        }
    }
}

// In your configure.swift, register the command:
// app.commands.use(GenerateMigrationCommand(), as: "generate-migration")

// Then run:
// vapor run generate-migration --preview
// vapor run generate-migration --name AddUserFields
