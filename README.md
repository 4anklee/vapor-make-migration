# Vapor Make Migration

[![Tests](https://github.com/yourusername/vapor-make-migration/actions/workflows/test.yml/badge.svg)](https://github.com/yourusername/vapor-make-migration/actions/workflows/test.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/yourusername/vapor-make-migration)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Auto-generate Vapor migration files by comparing Fluent models with your database schema.

## Overview

`vapor-make-migration` is a CLI tool that automatically creates Fluent migration files by:
1. Reading your current database schema
2. Comparing it with your Fluent models
3. Generating migration files for any differences

This eliminates the manual work of writing migrations and helps keep your database in sync with your models.

## Features

- **Multi-Database Support**: Works with PostgreSQL, MySQL, and SQLite
- **Automatic Schema Detection**: Introspects your database to understand the current state
- **Smart Diff Engine**: Identifies differences between models and database
- **Clean Migration Code**: Generates production-ready Fluent migration files
- **Preview Mode**: See changes before creating migration files
- **Comprehensive**: Handles tables, columns, constraints, and relationships

## Installation

### As a CLI Tool

```bash
git clone https://github.com/yourusername/vapor-make-migration.git
cd vapor-make-migration
swift build -c release
cp .build/release/vapor-make-migration /usr/local/bin/
```

### As a Package Dependency

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/vapor-make-migration.git", from: "1.0.0")
]
```

## Usage

### Basic Command

```bash
vapor-make-migration --database postgres://user:password@localhost/mydb --name AddUserTable
```

### Options

- `--database, -d`: Database connection string (required)
- `--name, -n`: Name for the migration (default: "AutoMigration")
- `--migrations-path`: Path to migrations directory (default: "./Sources/App/Migrations")
- `--preview`: Preview changes without creating files
- `--verbose`: Show detailed output
- `--project-path, -p`: Path to your Vapor project (default: ".")

### Database Connection Strings

**PostgreSQL:**
```bash
postgres://username:password@localhost:5432/database
```

**MySQL:**
```bash
mysql://username:password@localhost:3306/database
```

**SQLite:**
```bash
sqlite:///path/to/database.sqlite
```

### Examples

**Preview mode (see what would be generated):**
```bash
vapor-make-migration -d postgres://vapor:vapor@localhost/mydb --preview
```

**Generate migration with custom name:**
```bash
vapor-make-migration -d postgres://vapor:vapor@localhost/mydb -n AddProductsTable
```

**Specify migrations directory:**
```bash
vapor-make-migration -d postgres://vapor:vapor@localhost/mydb \
  --migrations-path ./Sources/App/Migrations \
  -n UpdateUserSchema
```

## How It Works

### 1. Database Introspection

The tool connects to your database and reads the complete schema:
- Tables and their columns
- Data types
- Constraints (primary keys, foreign keys, unique constraints)
- Nullability and default values

### 2. Model Introspection

Scans your Fluent models to understand the desired schema:
- Model properties and their types
- Field configurations
- Relationships (@Parent, @Children, etc.)

### 3. Schema Comparison

Compares the two schemas and identifies:
- New tables to create
- Tables to drop
- Columns to add/remove/modify
- Constraints to add/remove

### 4. Migration Generation

Generates clean, readable Fluent migration code:

```swift
import Fluent

struct CreateUser20250125120000: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .delete()
    }
}
```

## Integration with Vapor Projects

### Programmatic Usage

You can integrate the core library directly into your Vapor app:

```swift
import MigrationCore
import Fluent

func generateMigration(app: Application) async throws {
    // Introspect current database
    let dbIntrospector = DatabaseIntrospector(database: app.db)
    let currentSchema = try await dbIntrospector.introspect()

    // Introspect models
    let modelIntrospector = ModelIntrospector()
    let desiredSchema = try modelIntrospector.introspect(models: [
        User.self,
        Product.self,
        Order.self
    ])

    // Compare and generate migration
    let comparator = SchemaComparator()
    let diff = comparator.compare(current: currentSchema, desired: desiredSchema)

    let generator = MigrationGenerator()
    let migrationCode = generator.generate(diff: diff, name: "AutoMigration")

    print(migrationCode)
}
```

### Register Generated Migrations

After generating a migration file, register it in your `configure.swift`:

```swift
import Fluent

public func configure(_ app: Application) throws {
    // ... database configuration ...

    // Add your generated migration
    app.migrations.add(CreateUser20250125120000())

    // ... other setup ...
}
```

Then run:
```bash
vapor run migrate
```

## Architecture

The project is organized into modular components:

### Core Modules

**SchemaModel.swift**
- Defines data structures for database schemas
- `TableSchema`, `ColumnSchema`, `ConstraintSchema`
- Platform-agnostic representation

**DatabaseIntrospector.swift**
- Reads current database schema
- Supports PostgreSQL, MySQL, SQLite
- Uses information_schema and system tables

**ModelIntrospector.swift**
- Scans Fluent models using reflection
- Extracts field types and relationships
- Builds desired schema representation

**SchemaDiff.swift**
- Compares two schemas
- Identifies all differences
- Creates change set for migrations

**MigrationGenerator.swift**
- Generates Swift migration code
- Handles all Fluent migration operations
- Creates both prepare() and revert() methods

## Supported Changes

### Tables
- [x] Create table
- [x] Drop table
- [ ] Rename table (manual intervention required)

### Columns
- [x] Add column
- [x] Drop column
- [x] Modify column type
- [x] Change nullability
- [x] Add/remove unique constraint

### Constraints
- [x] Primary keys
- [x] Foreign keys
- [x] Unique constraints
- [ ] Check constraints (database-specific)
- [x] Indexes

### Data Types
- [x] All standard SQL types
- [x] Int, String, Bool, Float, Double
- [x] Date, DateTime, Time
- [x] UUID, JSON, Data
- [x] Custom types

## Limitations & Roadmap

### Current Limitations

1. **Model Discovery**: Requires manual model registration (Swift reflection limitations)
2. **Rename Detection**: Cannot automatically detect renamed tables/columns
3. **Data Migration**: Only handles schema, not data transformations
4. **Complex Constraints**: Some database-specific constraints need manual work

### Roadmap

- [ ] Automatic model discovery via source file parsing
- [ ] Data migration support
- [ ] Rename detection via heuristics
- [ ] Rollback safety checks
- [ ] Integration with Vapor CLI
- [ ] Migration history tracking
- [ ] Seed data generation
- [ ] Migration squashing

## Contributing

Contributions are welcome! This tool aims to eventually merge into Vapor's official toolchain.

### Development Setup

```bash
git clone https://github.com/yourusername/vapor-make-migration.git
cd vapor-make-migration
swift build
swift test
```

### Running Tests

```bash
swift test
```

## Safety & Best Practices

1. **Always Review**: Never run generated migrations without reviewing them first
2. **Use Preview**: Run with `--preview` to see changes before generating
3. **Version Control**: Commit migrations to your repository
4. **Test Migrations**: Test in development before production
5. **Backup Data**: Always backup before running migrations in production

## License

MIT License - see LICENSE file for details

## Credits

Built for the Vapor community with the goal of making database migrations easier and more automated.

## Support

- File issues on GitHub
- Join the Vapor Discord
- Read the Vapor documentation: https://docs.vapor.codes
