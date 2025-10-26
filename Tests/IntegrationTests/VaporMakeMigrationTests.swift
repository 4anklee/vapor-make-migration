import Testing
@testable import MigrationCore

// MARK: - Schema Model Tests

@Suite("Schema Model Tests")
struct SchemaModelTests {

    @Test("Table schemas with same properties are equal")
    func tableSchemaEquality() {
        let table1 = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255))
            ]
        )

        let table2 = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255))
            ]
        )

        #expect(table1 == table2)
    }

    @Test("Column data types map to correct SQL types")
    func columnDataTypes() {
        let stringColumn = ColumnSchema(name: "name", dataType: .string(length: 255))
        #expect(stringColumn.dataType.sqlType == "VARCHAR(255)")

        let textColumn = ColumnSchema(name: "description", dataType: .text)
        #expect(textColumn.dataType.sqlType == "TEXT")

        let intColumn = ColumnSchema(name: "age", dataType: .int32)
        #expect(intColumn.dataType.sqlType == "INTEGER")

        let uuidColumn = ColumnSchema(name: "id", dataType: .uuid)
        #expect(uuidColumn.dataType.sqlType == "UUID")
    }

    @Test("Constraint types are created correctly")
    func constraintTypes() {
        let pkConstraint = ConstraintSchema(
            type: .primaryKey,
            columns: ["id"],
            name: "users_pkey"
        )

        #expect(pkConstraint.columns == ["id"])
        #expect(pkConstraint.name == "users_pkey")

        let fkRef = ConstraintSchema.ConstraintType.ForeignKeyReference(
            table: "users",
            column: "id",
            onDelete: .cascade
        )

        let fkConstraint = ConstraintSchema(
            type: .foreignKey(references: fkRef),
            columns: ["user_id"]
        )

        #expect(fkConstraint.columns == ["user_id"])
    }
}

// MARK: - Schema Diff Tests

@Suite("Schema Diff Tests")
struct SchemaDiffTests {

    @Test("Empty diff when schemas are identical")
    func emptyDiff() {
        let schema = DatabaseSchema(tables: [])
        let comparator = SchemaComparator()
        let diff = comparator.compare(current: schema, desired: schema)

        #expect(diff.isEmpty)
        #expect(diff.changes.count == 0)
    }

    @Test("Detects new table creation")
    func createTableDiff() {
        let current = DatabaseSchema(tables: [])

        let newTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255))
            ]
        )
        let desired = DatabaseSchema(tables: [newTable])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        #expect(!diff.isEmpty)
        #expect(diff.changes.count == 1)

        if case .createTable(let table) = diff.changes.first {
            #expect(table.name == "users")
            #expect(table.columns.count == 2)
        } else {
            Issue.record("Expected createTable change")
        }
    }

    @Test("Detects table deletion")
    func dropTableDiff() {
        let oldTable = TableSchema(
            name: "old_table",
            columns: [ColumnSchema(name: "id", dataType: .uuid)]
        )
        let current = DatabaseSchema(tables: [oldTable])
        let desired = DatabaseSchema(tables: [])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        #expect(diff.changes.count == 1)

        if case .dropTable(let tableName) = diff.changes.first {
            #expect(tableName == "old_table")
        } else {
            Issue.record("Expected dropTable change")
        }
    }

    @Test("Detects new column addition")
    func addColumnDiff() {
        let currentTable = TableSchema(
            name: "users",
            columns: [ColumnSchema(name: "id", dataType: .uuid)]
        )

        let desiredTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "email", dataType: .string(length: nil))
            ]
        )

        let current = DatabaseSchema(tables: [currentTable])
        let desired = DatabaseSchema(tables: [desiredTable])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        #expect(diff.changes.count == 1)

        if case .addColumn(let table, let column) = diff.changes.first {
            #expect(table == "users")
            #expect(column.name == "email")
        } else {
            Issue.record("Expected addColumn change")
        }
    }

    @Test("Detects column removal")
    func dropColumnDiff() {
        let currentTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "old_field", dataType: .string(length: nil))
            ]
        )

        let desiredTable = TableSchema(
            name: "users",
            columns: [ColumnSchema(name: "id", dataType: .uuid)]
        )

        let current = DatabaseSchema(tables: [currentTable])
        let desired = DatabaseSchema(tables: [desiredTable])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        #expect(diff.changes.count == 1)

        if case .dropColumn(let table, let columnName) = diff.changes.first {
            #expect(table == "users")
            #expect(columnName == "old_field")
        } else {
            Issue.record("Expected dropColumn change")
        }
    }

    @Test("Detects column modifications")
    func modifyColumnDiff() {
        let currentTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "age", dataType: .int32, isOptional: true)
            ]
        )

        let desiredTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "age", dataType: .int32, isOptional: false)
            ]
        )

        let current = DatabaseSchema(tables: [currentTable])
        let desired = DatabaseSchema(tables: [desiredTable])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        #expect(diff.changes.count == 1)

        if case .modifyColumn(let table, let columnName, _, _) = diff.changes.first {
            #expect(table == "users")
            #expect(columnName == "age")
        } else {
            Issue.record("Expected modifyColumn change")
        }
    }

    @Test("Handles multiple simultaneous changes")
    func multipleChanges() {
        let currentTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "old_field", dataType: .string(length: nil))
            ]
        )

        let desiredTable = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255)),
                ColumnSchema(name: "email", dataType: .string(length: nil))
            ]
        )

        let newTable = TableSchema(
            name: "products",
            columns: [ColumnSchema(name: "id", dataType: .uuid)]
        )

        let current = DatabaseSchema(tables: [currentTable])
        let desired = DatabaseSchema(tables: [desiredTable, newTable])

        let comparator = SchemaComparator()
        let diff = comparator.compare(current: current, desired: desired)

        // Should have: createTable, addColumn (x2), dropColumn
        #expect(diff.changes.count == 4)
    }
}

// MARK: - Migration Generator Tests

@Suite("Migration Generator Tests")
struct MigrationGeneratorTests {

    @Test("Generates CREATE TABLE migration")
    func generateCreateTable() {
        let table = TableSchema(
            name: "users",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255), isOptional: false),
                ColumnSchema(name: "email", dataType: .string(length: nil), isOptional: false, isUnique: true)
            ],
            constraints: [
                ConstraintSchema(type: .primaryKey, columns: ["id"], name: "users_pkey")
            ]
        )

        let diff = SchemaDiff(changes: [.createTable(table)])
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "CreateUsers")

        #expect(code.contains("struct CreateCreateusers"))
        #expect(code.contains("AsyncMigration"))
        #expect(code.contains("func prepare(on database: Database)"))
        #expect(code.contains("func revert(on database: Database)"))
        #expect(code.contains("database.schema(\"users\")"))
        #expect(code.contains(".id()"))
        #expect(code.contains(".field(\"name\""))
        #expect(code.contains(".required()"))
        #expect(code.contains(".unique()"))
        #expect(code.contains(".create()"))
    }

    @Test("Generates ADD COLUMN migration")
    func generateAddColumn() {
        let newColumn = ColumnSchema(
            name: "age",
            dataType: .int32,
            isOptional: true
        )

        let diff = SchemaDiff(changes: [.addColumn(table: "users", column: newColumn)])
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "AddUserAge")

        #expect(code.contains("struct CreateAdduserage"))
        #expect(code.contains("database.schema(\"users\")"))
        #expect(code.contains(".field(\"age\""))
        #expect(code.contains(".update()"))
    }

    @Test("Generates DROP TABLE migration")
    func generateDropTable() {
        let diff = SchemaDiff(changes: [.dropTable("old_table")])
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "DropOldTable")

        #expect(code.contains("database.schema(\"old_table\")"))
        #expect(code.contains(".delete()"))
    }

    @Test("Generates DROP COLUMN migration")
    func generateDropColumn() {
        let diff = SchemaDiff(changes: [.dropColumn(table: "users", columnName: "old_field")])
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "RemoveOldField")

        #expect(code.contains("database.schema(\"users\")"))
        #expect(code.contains(".deleteField(\"old_field\")"))
        #expect(code.contains(".update()"))
    }

    @Test("Handles multiple operations in one migration")
    func generateMultipleChanges() {
        let newColumn = ColumnSchema(name: "age", dataType: .int32)
        let changes: [SchemaChange] = [
            .addColumn(table: "users", column: newColumn),
            .dropColumn(table: "users", columnName: "old_field")
        ]

        let diff = SchemaDiff(changes: changes)
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "UpdateUsers")

        #expect(code.contains("struct CreateUpdateusers"))
        #expect(code.contains("AsyncMigration"))
        #expect(code.contains("age"))
        #expect(code.contains("old_field"))
    }

    @Test("Generated code has correct structure")
    func generatedCodeStructure() {
        let table = TableSchema(
            name: "products",
            columns: [
                ColumnSchema(name: "id", dataType: .uuid),
                ColumnSchema(name: "name", dataType: .string(length: 255))
            ]
        )

        let diff = SchemaDiff(changes: [.createTable(table)])
        let generator = MigrationGenerator()
        let code = generator.generate(diff: diff, name: "CreateProducts")

        #expect(code.contains("import Fluent"))
        #expect(code.contains("struct"))
        #expect(code.contains(": AsyncMigration"))
        #expect(code.contains("func prepare(on database: Database) async throws"))
        #expect(code.contains("func revert(on database: Database) async throws"))
        #expect(code.contains("Createproducts"))
    }
}

// MARK: - Database Schema Tests

@Suite("Database Schema Tests")
struct DatabaseSchemaTests {

    @Test("Can lookup tables by name")
    func tableLookup() {
        let table1 = TableSchema(name: "users", columns: [])
        let table2 = TableSchema(name: "products", columns: [])

        let schema = DatabaseSchema(tables: [table1, table2])

        #expect(schema.table(named: "users") != nil)
        #expect(schema.table(named: "products") != nil)
        #expect(schema.table(named: "nonexistent") == nil)
        #expect(schema.table(named: "users")?.name == "users")
    }

    @Test("Empty schema has no tables")
    func emptySchema() {
        let schema = DatabaseSchema(tables: [])
        #expect(schema.tables.count == 0)
        #expect(schema.table(named: "anything") == nil)
    }
}

// MARK: - Schema Change Description Tests

@Suite("Schema Change Description Tests")
struct SchemaChangeDescriptionTests {

    @Test("Change descriptions are human-readable", arguments: [
        (SchemaChange.createTable(TableSchema(name: "users", columns: [])), "Create table 'users'"),
        (SchemaChange.dropTable("old_table"), "Drop table 'old_table'"),
        (SchemaChange.renameTable(from: "old_name", to: "new_name"), "Rename table 'old_name' to 'new_name'"),
        (SchemaChange.addColumn(table: "users", column: ColumnSchema(name: "email", dataType: .string(length: nil))), "Add column 'email' to table 'users'"),
        (SchemaChange.dropColumn(table: "users", columnName: "old_field"), "Drop column 'old_field' from table 'users'"),
    ])
    func changeDescriptions(change: SchemaChange, expected: String) {
        #expect(change.description == expected)
    }

    @Test("Constraint change descriptions")
    func constraintDescriptions() {
        let constraint = ConstraintSchema(type: .unique, columns: ["email"])
        let addConstraint = SchemaChange.addConstraint(table: "users", constraint: constraint)
        #expect(addConstraint.description == "Add constraint to table 'users'")

        let dropConstraint = SchemaChange.dropConstraint(table: "users", constraintName: "users_email_key")
        #expect(dropConstraint.description == "Drop constraint 'users_email_key' from table 'users'")
    }

    @Test("Modify column description")
    func modifyColumnDescription() {
        let column = ColumnSchema(name: "age", dataType: .int32)
        let modifyColumn = SchemaChange.modifyColumn(
            table: "users",
            columnName: "age",
            from: column,
            to: column
        )
        #expect(modifyColumn.description == "Modify column 'age' in table 'users'")
    }
}

// MARK: - Constraint Referential Action Tests

@Suite("Constraint Referential Actions")
struct ConstraintReferentialActionTests {

    @Test("Referential actions have correct SQL values", arguments: [
        (ConstraintSchema.ConstraintType.ReferentialAction.cascade, "CASCADE"),
        (.restrict, "RESTRICT"),
        (.setNull, "SET NULL"),
        (.setDefault, "SET DEFAULT"),
        (.noAction, "NO ACTION")
    ])
    func referentialActions(action: ConstraintSchema.ConstraintType.ReferentialAction, expected: String) {
        #expect(action.rawValue == expected)
    }
}
