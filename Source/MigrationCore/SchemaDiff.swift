import Foundation

/// Represents differences between two database schemas
public struct SchemaDiff: Equatable, Sendable {
    public var changes: [SchemaChange]

    public init(changes: [SchemaChange] = []) {
        self.changes = changes
    }

    public var isEmpty: Bool {
        changes.isEmpty
    }
}

/// Represents a single change in the schema
public enum SchemaChange: Equatable, Sendable {
    case createTable(TableSchema)
    case dropTable(String)
    case renameTable(from: String, to: String)
    case addColumn(table: String, column: ColumnSchema)
    case dropColumn(table: String, columnName: String)
    case modifyColumn(table: String, columnName: String, from: ColumnSchema, to: ColumnSchema)
    case addConstraint(table: String, constraint: ConstraintSchema)
    case dropConstraint(table: String, constraintName: String)

    public var description: String {
        switch self {
        case .createTable(let table):
            return "Create table '\(table.name)'"
        case .dropTable(let name):
            return "Drop table '\(name)'"
        case .renameTable(let from, let to):
            return "Rename table '\(from)' to '\(to)'"
        case .addColumn(let table, let column):
            return "Add column '\(column.name)' to table '\(table)'"
        case .dropColumn(let table, let columnName):
            return "Drop column '\(columnName)' from table '\(table)'"
        case .modifyColumn(let table, let columnName, _, _):
            return "Modify column '\(columnName)' in table '\(table)'"
        case .addConstraint(let table, let constraint):
            return "Add constraint to table '\(table)'"
        case .dropConstraint(let table, let constraintName):
            return "Drop constraint '\(constraintName)' from table '\(table)'"
        }
    }
}

/// Compares two schemas and generates a diff
public struct SchemaComparator {
    public init() {}

    public func compare(current: DatabaseSchema, desired: DatabaseSchema) -> SchemaDiff {
        var changes: [SchemaChange] = []

        // Find new tables
        for desiredTable in desired.tables {
            if current.table(named: desiredTable.name) == nil {
                changes.append(.createTable(desiredTable))
            }
        }

        // Find dropped tables
        for currentTable in current.tables {
            if desired.table(named: currentTable.name) == nil {
                changes.append(.dropTable(currentTable.name))
            }
        }

        // Find modified tables
        for desiredTable in desired.tables {
            if let currentTable = current.table(named: desiredTable.name) {
                let tableChanges = compareTable(current: currentTable, desired: desiredTable)
                changes.append(contentsOf: tableChanges)
            }
        }

        return SchemaDiff(changes: changes)
    }

    private func compareTable(current: TableSchema, desired: TableSchema) -> [SchemaChange] {
        var changes: [SchemaChange] = []

        // Find new columns
        for desiredColumn in desired.columns {
            if !current.columns.contains(where: { $0.name == desiredColumn.name }) {
                changes.append(.addColumn(table: desired.name, column: desiredColumn))
            }
        }

        // Find dropped columns
        for currentColumn in current.columns {
            if !desired.columns.contains(where: { $0.name == currentColumn.name }) {
                changes.append(.dropColumn(table: current.name, columnName: currentColumn.name))
            }
        }

        // Find modified columns
        for desiredColumn in desired.columns {
            if let currentColumn = current.columns.first(where: { $0.name == desiredColumn.name }),
               currentColumn != desiredColumn {
                changes.append(.modifyColumn(
                    table: current.name,
                    columnName: currentColumn.name,
                    from: currentColumn,
                    to: desiredColumn
                ))
            }
        }

        // Find new constraints
        for desiredConstraint in desired.constraints {
            if !current.constraints.contains(desiredConstraint) {
                changes.append(.addConstraint(table: desired.name, constraint: desiredConstraint))
            }
        }

        // Find dropped constraints
        for currentConstraint in current.constraints {
            if !desired.constraints.contains(currentConstraint),
               let name = currentConstraint.name {
                changes.append(.dropConstraint(table: current.name, constraintName: name))
            }
        }

        return changes
    }
}
