# Usage Guide for Vapor Make Migration

This guide shows you how to use `vapor-make-migration` to automatically generate migration files.

## Installation

### Option 1: Standalone CLI Tool

```bash
# Clone and build
git clone <your-repo-url>
cd vapor-make-migration
swift build -c release

# Install (optional)
cp .build/release/vapor-make-migration /usr/local/bin/
```

### Option 2: Integrate into Your Vapor Project

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/vapor-make-migration.git", from: "1.0.0")
]

targets: [
    .target(
        name: "App",
        dependencies: [
            // ... other dependencies
            .product(name: "VaporMakeCommand", package: "vapor-make-migration"),
        ]
    )
]
```

Then in your `configure.swift`, register the command:

```swift
import VaporMakeCommand

public func configure(_ app: Application) throws {
    // ... other configuration
    
    // Register the makemigration command
    app.commands.use(MakeMigrationCommandWithRegistry<AppModelRegistry>(), as: "makemigration")
}
```

Create a model registry:

```swift
import VaporMakeCommand
import Fluent

struct AppModelRegistry: ModelRegistry {
    static var models: [any Model.Type] {
        [
            User.self,
            Product.self,
            Order.self,
            // Add all your models here
        ]
    }
}
```

## Using the Standalone CLI

### Basic Usage

```bash
# Preview what would be generated
vapor-make-migration \
  --database postgres://user:password@localhost/mydb \
  --preview

# Generate a migration file
vapor-make-migration \
  --database postgres://user:password@localhost/mydb \
  --name AddUserTable \
  --migrations-path ./Sources/App/Migrations
```

### Database Connection Strings

**PostgreSQL:**
```bash
--database postgres://username:password@localhost:5432/database_name
```

**MySQL:**
```bash
--database mysql://username:password@localhost:3306/database_name
```

**SQLite:**
```bash
--database sqlite:///path/to/database.db
```

### CLI Options

- `--database, -d`: Database connection string (required)
- `--name, -n`: Name for the migration (default: "AutoMigration")
- `--migrations-path`: Path to migrations directory (default: "./Sources/App/Migrations")
- `--preview`: Preview changes without creating files
- `--verbose`: Show detailed output

## Using as Vapor Command

Once integrated into your project:

```bash
# Preview changes
vapor run makemigration --preview

# Generate migration with custom name
vapor run makemigration --name AddProductFields

# Specify custom migrations path
vapor run makemigration --path ./Sources/App/MyMigrations --name UpdateUsers
```

## Example Workflow

### 1. Define Your Models

```swift
// User.swift
import Fluent
import Vapor

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
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
}
```

### 2. Run Your App Once

Make sure your database is accessible and your app can connect to it.

### 3. Generate Migration

```bash
# Using CLI
vapor-make-migration -d postgres://vapor:vapor@localhost/mydb --preview

# Using Vapor command
vapor run makemigration --preview
```

### 4. Review Output

You'll see something like:

```
Vapor Migration Generator
========================================
Reading current database schema...
Found 2 tables in database

Analyzing models from registry...
Found 3 models

Comparing schemas...

Detected changes:
   1. Create table 'products'
   2. Add column 'age' to table 'users'

Preview mode - no files will be created
========================================
import Fluent

struct CreateProducts20251025120000: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("products")
            .id()
            .field("name", .string, .required)
            .field("price", .double, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("products")
            .delete()
    }
}
========================================
```

### 5. Generate the File

```bash
vapor run makemigration --name AddProducts
```

### 6. Register the Migration

In your `configure.swift`:

```swift
public func configure(_ app: Application) throws {
    // ... database configuration
    
    // Register migrations
    app.migrations.add(CreateProducts20251025120000())
    
    // ... other setup
}
```

### 7. Run Migrations

```bash
vapor run migrate
```

## Advanced Usage

### Custom Model Discovery

Create your own model introspection logic:

```swift
import MigrationCore
import Fluent

func discoverModels(in app: Application) -> [any Model.Type] {
    // Your custom logic to discover models
    // Could scan files, use reflection, etc.
    return [User.self, Product.self]
}
```

### Programmatic Usage

```swift
import MigrationCore

func generateMigration(app: Application) async throws {
    // 1. Introspect database
    let dbIntrospector = DatabaseIntrospector(database: app.db)
    let currentSchema = try await dbIntrospector.introspect()
    
    // 2. Introspect models
    let modelIntrospector = ModelIntrospector()
    let desiredSchema = try modelIntrospector.introspect(models: [
        User.self,
        Product.self
    ])
    
    // 3. Compare
    let comparator = SchemaComparator()
    let diff = comparator.compare(current: currentSchema, desired: desiredSchema)
    
    // 4. Generate
    let generator = MigrationGenerator()
    let code = generator.generate(diff: diff, name: "MyMigration")
    
    print(code)
}
```

## Tips and Best Practices

1. **Always Preview First**: Use `--preview` to see what will be generated
2. **Descriptive Names**: Use meaningful migration names like `AddUserAge` or `CreateProductsTable`
3. **Review Generated Code**: Always review the generated migration before running it
4. **Test in Development**: Test migrations in development before production
5. **Version Control**: Commit generated migrations to your repository
6. **Backup Data**: Always backup before running migrations in production
7. **One Change at a Time**: Generate separate migrations for logically distinct changes

## Troubleshooting

### "Cannot connect to database"

Make sure:
- Database is running
- Connection string is correct
- User has proper permissions

### "No changes detected"

This means your database already matches your models. This is good!

### "Unknown field type"

Some complex Fluent field types may not be automatically detected. You may need to manually create migrations for these.

### Generated migration needs adjustments

It's perfectly fine to manually edit the generated migration. The tool provides a starting point, but you have full control over the final migration code.

## Limitations

- **Model Discovery**: The standalone CLI cannot automatically discover models. You need to use the integrated Vapor command with a model registry.
- **Complex Relationships**: Some complex relationships may need manual adjustment.
- **Rename Detection**: Cannot automatically detect renamed columns/tables.
- **Data Migrations**: Only handles schema changes, not data transformations.

## Next Steps

- Read the [README.md](README.md) for more details
- Check out the [Examples](Examples/) directory
- Contribute to the project on GitHub
