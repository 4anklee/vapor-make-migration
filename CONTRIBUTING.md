# Contributing to Vapor Make Migration

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Be respectful and inclusive. We're all here to build something great together.

## Getting Started

1. **Fork the repository**
   ```bash
   gh repo fork yourusername/vapor-make-migration
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/vapor-make-migration.git
   cd vapor-make-migration
   ```

3. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

4. **Build and test**
   ```bash
   swift build
   swift test
   ```

## Development Workflow

### Making Changes

1. Write your code
2. Add tests for new functionality
3. Ensure all tests pass: `swift test`
4. Update documentation if needed
5. Commit your changes with clear messages

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add support for MySQL constraints introspection
fix: resolve issue with UUID type mapping
docs: update installation instructions
test: add tests for schema comparison
refactor: simplify migration generator code
```

Prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

### Testing

All new features must include tests:

```swift
@Suite("Your Feature Tests")
struct YourFeatureTests {

    @Test("Describe what this tests")
    func testSomething() {
        #expect(someCondition == true)
    }
}
```

Run tests with:
```bash
swift test                    # Run all tests
swift test --filter YourTest  # Run specific test
```

### Code Style

- Follow Swift naming conventions
- Use clear, descriptive variable names
- Add comments for complex logic
- Keep functions focused and small
- Use modern Swift features (async/await, etc.)

Example:
```swift
/// Generates migration code from schema differences
public struct MigrationGenerator {
    public init() {}

    /// Generates Swift migration file content
    /// - Parameters:
    ///   - diff: The schema differences to migrate
    ///   - name: Name for the migration
    /// - Returns: Swift migration code as a string
    public func generate(diff: SchemaDiff, name: String) -> String {
        // Implementation
    }
}
```

## Pull Request Process

1. **Update your fork**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request**
   - Use the PR template
   - Link related issues
   - Provide clear description
   - Add screenshots if UI-related

4. **Code Review**
   - Address review comments
   - Push additional commits if needed
   - Tests must pass

5. **Merge**
   - PR will be merged by maintainers
   - Your branch will be deleted

## Project Structure

```
vapor-make-migration/
├── Source/
│   ├── MigrationCore/           # Core library (reusable)
│   │   ├── SchemaModel.swift    # Data structures
│   │   ├── DatabaseIntrospector.swift  # DB reading
│   │   ├── ModelIntrospector.swift     # Model scanning
│   │   ├── SchemaDiff.swift     # Comparison logic
│   │   └── MigrationGenerator.swift    # Code generation
│   ├── VaporMakeMigration/      # CLI tool
│   │   └── Main.swift
│   └── VaporMakeCommand/        # Vapor integration
│       └── MakeMigrationCommand.swift
├── Tests/
│   └── IntegrationTests/
├── .github/
│   └── workflows/               # CI/CD
└── Documentation/
```

## Areas for Contribution

### High Priority

- [ ] Automatic model discovery via source file parsing
- [ ] Support for more database types (MSSQL, Oracle)
- [ ] Rename detection heuristics
- [ ] Data migration support
- [ ] Better error messages

### Medium Priority

- [ ] Performance optimization for large schemas
- [ ] Migration rollback safety checks
- [ ] Schema validation
- [ ] Interactive CLI mode

### Documentation

- [ ] More usage examples
- [ ] Video tutorials
- [ ] Blog posts
- [ ] API documentation

### Testing

- [ ] Integration tests with real databases
- [ ] Performance benchmarks
- [ ] Edge case coverage

## Release Process

Maintainers follow semantic versioning:

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

## Questions?

- Open a [Discussion](https://github.com/yourusername/vapor-make-migration/discussions)
- Ask in [Vapor Discord](https://discord.gg/vapor)
- Check existing [Issues](https://github.com/yourusername/vapor-make-migration/issues)

## Thank You!

Your contributions make this project better for everyone! 🎉
