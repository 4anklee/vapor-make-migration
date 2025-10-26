# Testing Documentation

This document describes the test suite for vapor-make-migration.

## Test Overview

**Total Tests: 22** (including parameterized test cases)
**Test Suites: 6**
**Status: ✅ All Passing**
**Framework: Swift Testing (Modern)**

## Test Suites

### 1. SchemaModelTests (3 tests)
Tests for the core data structures:
- `testTableSchemaEquality` - Verifies table schema equality comparison
- `testColumnSchemaDataTypes` - Tests SQL type mapping for all data types
- `testConstraintTypes` - Validates constraint type definitions

### 2. SchemaDiffTests (7 tests)
Tests for schema comparison logic:
- `testEmptyDiff` - Verifies no changes when schemas match
- `testCreateTableDiff` - Detects new table creation
- `testDropTableDiff` - Detects table deletion
- `testAddColumnDiff` - Identifies added columns
- `testDropColumnDiff` - Identifies removed columns
- `testModifyColumnDiff` - Detects column modifications
- `testMultipleChanges` - Handles complex multi-change scenarios

### 3. MigrationGeneratorTests (6 tests)
Tests for migration code generation:
- `testGenerateCreateTable` - Generates CREATE TABLE migration
- `testGenerateAddColumn` - Generates ADD COLUMN migration
- `testGenerateDropTable` - Generates DROP TABLE migration
- `testGenerateDropColumn` - Generates DROP COLUMN migration
- `testGenerateMultipleChanges` - Handles multiple operations
- `testGeneratedCodeStructure` - Validates overall code structure

### 4. DatabaseSchemaTests (2 tests)
Tests for database schema operations:
- `testTableLookup` - Verifies table lookup functionality
- `testEmptySchema` - Handles empty schema correctly

### 5. SchemaChangeDescriptionTests (1 test)
Tests for human-readable change descriptions:
- `testChangeDescriptions` - Validates all change type descriptions

### 6. ConstraintReferentialActionTests (1 test)
Tests for foreign key referential actions:
- `testReferentialActions` - Validates CASCADE, RESTRICT, SET NULL, etc.

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test Suite
```bash
swift test --filter SchemaDiffTests
```

### Run Specific Test
```bash
swift test --filter testCreateTableDiff
```

### Verbose Output
```bash
swift test --verbose
```

## Test Coverage

The test suite covers:

✅ **Schema Models**
- TableSchema, ColumnSchema, ConstraintSchema
- All data types (Int, String, UUID, Date, JSON, etc.)
- Foreign key constraints and referential actions

✅ **Schema Comparison**
- Empty diff detection
- Table operations (create, drop)
- Column operations (add, drop, modify)
- Constraint operations
- Multiple simultaneous changes

✅ **Migration Generation**
- Proper Swift code structure
- AsyncMigration conformance
- prepare() and revert() methods
- All schema operation types
- Code formatting and indentation

✅ **Edge Cases**
- Empty schemas
- No changes scenarios
- Complex multi-operation migrations

## Future Test Additions

Potential areas for additional testing:

- [ ] Database introspection with real databases (PostgreSQL, MySQL, SQLite)
- [ ] Model introspection with actual Fluent models
- [ ] End-to-end integration tests
- [ ] Performance tests for large schemas
- [ ] Error handling and edge cases
- [ ] File writing operations
- [ ] CLI argument parsing

## Contributing Tests

When adding new features, please:

1. Write tests first (TDD approach)
2. Ensure all existing tests still pass
3. Aim for high code coverage
4. Include both positive and negative test cases
5. Test edge cases and error conditions

## Test Quality Guidelines

- **Clear Names**: Test names should describe what they test
- **Single Purpose**: Each test should verify one specific behavior
- **Assertions**: Use descriptive failure messages
- **Independence**: Tests should not depend on each other
- **Fast**: Tests should run quickly for rapid feedback
