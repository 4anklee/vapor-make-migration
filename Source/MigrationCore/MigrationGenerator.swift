import Foundation

/// Generates Swift migration files from schema differences
public struct MigrationGenerator {
    public init() {}

    public func generate(diff: SchemaDiff, name: String) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .prefix(15)

        let className = "Create\(name.capitalized)\(timestamp)"

        var code = """
        import Fluent

        struct \(className): AsyncMigration {
            func prepare(on database: Database) async throws {
        """

        // Generate migration code
        for change in diff.changes {
            code += "\n" + generateChangeCode(change, indentation: 2)
        }

        code += """

            }

            func revert(on database: Database) async throws {
        """

        // Generate revert code
        for change in diff.changes.reversed() {
            code += "\n" + generateRevertCode(change, indentation: 2)
        }

        code += """

            }
        }
        """

        return code
    }

    private func generateChangeCode(_ change: SchemaChange, indentation: Int) -> String {
        let indent = String(repeating: " ", count: indentation * 4)

        switch change {
        case .createTable(let table):
            return generateCreateTable(table, indent: indent)

        case .dropTable(let name):
            return """
            \(indent)try await database.schema("\(name)")
            \(indent)    .delete()
            """

        case .addColumn(let table, let column):
            return generateAddColumn(table: table, column: column, indent: indent)

        case .dropColumn(let table, let columnName):
            return """
            \(indent)try await database.schema("\(table)")
            \(indent)    .deleteField("\(columnName)")
            \(indent)    .update()
            """

        case .modifyColumn(let table, _, _, let to):
            return generateModifyColumn(table: table, column: to, indent: indent)

        case .addConstraint(let table, let constraint):
            return generateAddConstraint(table: table, constraint: constraint, indent: indent)

        case .dropConstraint(let table, let constraintName):
            return """
            \(indent)// Note: Drop constraint '\(constraintName)' from '\(table)'
            \(indent)// Manual intervention may be required
            """

        case .renameTable(let from, let to):
            return """
            \(indent)// Note: Rename table '\(from)' to '\(to)'
            \(indent)// This requires manual SQL execution:
            \(indent)// try await database.raw("ALTER TABLE \(from) RENAME TO \(to)").run()
            """
        }
    }

    private func generateRevertCode(_ change: SchemaChange, indentation: Int) -> String {
        let indent = String(repeating: " ", count: indentation * 4)

        switch change {
        case .createTable(let table):
            return """
            \(indent)try await database.schema("\(table.name)")
            \(indent)    .delete()
            """

        case .dropTable(let name):
            return """
            \(indent)// Note: Cannot automatically recreate dropped table '\(name)'
            \(indent)// Manual intervention required
            """

        case .addColumn(let table, let column):
            return """
            \(indent)try await database.schema("\(table)")
            \(indent)    .deleteField("\(column.name)")
            \(indent)    .update()
            """

        case .dropColumn(let table, let column):
            return """
            \(indent)// Note: Cannot restore dropped column '\(column)' from '\(table)'
            \(indent)// Manual intervention required
            """

        case .modifyColumn(let table, _, let from, _):
            return generateModifyColumn(table: table, column: from, indent: indent)

        case .addConstraint:
            return """
            \(indent)// Note: Constraint removal in revert
            \(indent)// Manual intervention may be required
            """

        case .dropConstraint:
            return """
            \(indent)// Note: Constraint restoration in revert
            \(indent)// Manual intervention may be required
            """

        case .renameTable(let from, let to):
            return """
            \(indent)// Note: Rename table '\(to)' back to '\(from)'
            \(indent)// This requires manual SQL execution
            """
        }
    }

    private func generateCreateTable(_ table: TableSchema, indent: String) -> String {
        var code = """
        \(indent)try await database.schema("\(table.name)")
        """

        // Add ID field
        code += """

        \(indent)    .id()
        """

        // Add other columns
        for column in table.columns where column.name != "id" {
            code += "\n" + generateFieldDefinition(column, indent: indent + "    ")
        }

        // Add constraints
        for constraint in table.constraints where constraint.type != .primaryKey {
            code += "\n" + generateConstraintDefinition(constraint, indent: indent + "    ")
        }

        code += """

        \(indent)    .create()
        """

        return code
    }

    private func generateFieldDefinition(_ column: ColumnSchema, indent: String) -> String {
        var parts: [String] = []
        parts.append(".\(fluentFieldMethod(for: column.dataType))(\"\(column.name)\")")

        if !column.isOptional {
            parts.append(".required()")
        }

        if column.isUnique {
            parts.append(".unique()")
        }

        return parts.map { "\(indent)\($0)" }.joined(separator: "\n")
    }

    private func generateAddColumn(table: String, column: ColumnSchema, indent: String) -> String {
        var code = """
        \(indent)try await database.schema("\(table)")
        """

        code += "\n" + generateFieldDefinition(column, indent: indent + "    ")

        code += """

        \(indent)    .update()
        """

        return code
    }

    private func generateModifyColumn(table: String, column: ColumnSchema, indent: String) -> String {
        var code = """
        \(indent)try await database.schema("\(table)")
        """

        code += "\n" + generateFieldDefinition(column, indent: indent + "    ")

        code += """

        \(indent)    .update()
        """

        return code
    }

    private func generateConstraintDefinition(_ constraint: ConstraintSchema, indent: String) -> String {
        switch constraint.type {
        case .unique:
            let columns = constraint.columns.map { "\"\($0)\"" }.joined(separator: ", ")
            return "\(indent).unique(on: \(columns))"

        case .foreignKey(let ref):
            let column = constraint.columns.first ?? ""
            var code = "\(indent).foreignKey(\"\(column)\", references: \"\(ref.table)\", \"\(ref.column)\")"

            if let onDelete = ref.onDelete {
                code += ", onDelete: .\(fluentAction(onDelete))"
            }

            if let onUpdate = ref.onUpdate {
                code += ", onUpdate: .\(fluentAction(onUpdate))"
            }

            return code

        case .index:
            let columns = constraint.columns.map { "\"\($0)\"" }.joined(separator: ", ")
            return "\(indent)// Note: Add index on \(columns)"

        case .primaryKey:
            return ""
        }
    }

    private func generateAddConstraint(table: String, constraint: ConstraintSchema, indent: String) -> String {
        var code = """
        \(indent)try await database.schema("\(table)")
        """

        code += "\n" + generateConstraintDefinition(constraint, indent: indent + "    ")

        code += """

        \(indent)    .update()
        """

        return code
    }

    private func fluentFieldMethod(for dataType: ColumnSchema.DataType) -> String {
        switch dataType {
        case .int, .int32: return "field"
        case .int8: return "field"
        case .int16: return "field"
        case .int64: return "field"
        case .uint, .uint32: return "field"
        case .uint8: return "field"
        case .uint16: return "field"
        case .uint64: return "field"
        case .bool: return "field"
        case .string: return "field"
        case .text: return "field"
        case .double: return "field"
        case .float: return "field"
        case .date: return "field"
        case .datetime: return "field"
        case .time: return "field"
        case .uuid: return "field"
        case .data: return "field"
        case .json: return "field"
        case .custom: return "field"
        }
    }

    private func fluentDataType(for dataType: ColumnSchema.DataType) -> String {
        switch dataType {
        case .int, .int32: return ".int"
        case .int8: return ".int8"
        case .int16: return ".int16"
        case .int64: return ".int64"
        case .uint, .uint32: return ".uint"
        case .uint8: return ".uint8"
        case .uint16: return ".uint16"
        case .uint64: return ".uint64"
        case .bool: return ".bool"
        case .string(let length):
            if let length = length {
                return ".string(.max(\(length)))"
            }
            return ".string"
        case .text: return ".string"
        case .double: return ".double"
        case .float: return ".float"
        case .date: return ".date"
        case .datetime: return ".datetime"
        case .time: return ".time"
        case .uuid: return ".uuid"
        case .data: return ".data"
        case .json: return ".json"
        case .custom(let type): return ".custom(\"\(type)\")"
        }
    }

    private func fluentAction(_ action: ConstraintSchema.ConstraintType.ReferentialAction) -> String {
        switch action {
        case .cascade: return "cascade"
        case .restrict: return "restrict"
        case .setNull: return "setNull"
        case .setDefault: return "setDefault"
        case .noAction: return "noAction"
        }
    }
}

/// File writer for migration files
public struct MigrationFileWriter {
    private let basePath: String

    public init(basePath: String) {
        self.basePath = basePath
    }

    public func write(migrationCode: String, name: String) throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .prefix(15)

        let fileName = "Create\(name.capitalized)\(timestamp).swift"
        let filePath = (basePath as NSString).appendingPathComponent(fileName)

        try migrationCode.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
}
