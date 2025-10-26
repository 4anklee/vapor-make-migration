import Fluent
import FluentMySQLDriver
import FluentPostgresDriver
import FluentSQLiteDriver
import SQLKit
import Vapor

/// Introspects the current database schema
public struct DatabaseIntrospector {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func introspect() async throws -> DatabaseSchema {
        // Determine database type by checking the SQL database type
        if sql is PostgresDatabase {
            return try await introspectPostgreSQL()
        } else if sql is MySQLDatabase {
            return try await introspectMySQL()
        } else if sql is SQLiteDatabase {
            return try await introspectSQLite()
        } else {
            throw IntrospectionError.unsupportedDatabase(DatabaseID(string: "unknown"))
        }
    }

    private var sql: any SQLDatabase {
        get throws {
            guard let sqlDatabase = database as? any SQLDatabase else {
                throw IntrospectionError.unsupportedDatabase(database.context.configuration.id)
            }
            return sqlDatabase
        }
    }

    // MARK: - PostgreSQL

    private func introspectPostgreSQL() async throws -> DatabaseSchema {
        // Get all tables
        let tableRows = try await sql.raw(
            """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = 'public'
                AND table_type = 'BASE TABLE'
                AND table_name != '_fluent_migrations'
                ORDER BY table_name
            """
        ).all()

        var tables: [TableSchema] = []

        for row in tableRows {
            guard let tableName = try? row.decode(column: "table_name", as: String.self) else {
                continue
            }

            let columns = try await introspectPostgreSQLColumns(tableName: tableName)
            let constraints = try await introspectPostgreSQLConstraints(tableName: tableName)

            tables.append(
                TableSchema(
                    name: tableName,
                    columns: columns,
                    constraints: constraints
                ))
        }

        return DatabaseSchema(tables: tables)
    }

    private func introspectPostgreSQLColumns(tableName: String) async throws -> [ColumnSchema] {
        let rows = try await sql.raw(
            """
                SELECT
                    column_name,
                    data_type,
                    udt_name,
                    character_maximum_length,
                    is_nullable,
                    column_default
                FROM information_schema.columns
                WHERE table_schema = 'public'
                AND table_name = \(bind: tableName)
                ORDER BY ordinal_position
            """
        ).all()

        var columns: [ColumnSchema] = []

        for row in rows {
            guard let columnName = try? row.decode(column: "column_name", as: String.self),
                let udtName = try? row.decode(column: "udt_name", as: String.self)
            else { continue }

            let isNullable = (try? row.decode(column: "is_nullable", as: String.self)) == "YES"
            let maxLength = try? row.decode(column: "character_maximum_length", as: Int?.self)
            let defaultValue = try? row.decode(column: "column_default", as: String?.self)

            let dataType = mapPostgreSQLType(udtName: udtName, maxLength: maxLength)

            columns.append(
                ColumnSchema(
                    name: columnName,
                    dataType: dataType,
                    isOptional: isNullable,
                    isUnique: false,
                    defaultValue: defaultValue
                ))
        }

        return columns
    }

    private func introspectPostgreSQLConstraints(tableName: String) async throws
        -> [ConstraintSchema]
    {
        let rows = try await sql.raw(
            """
                SELECT
                    tc.constraint_name,
                    tc.constraint_type,
                    kcu.column_name,
                    ccu.table_name AS foreign_table_name,
                    ccu.column_name AS foreign_column_name,
                    rc.delete_rule,
                    rc.update_rule
                FROM information_schema.table_constraints AS tc
                LEFT JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                    AND tc.table_schema = kcu.table_schema
                LEFT JOIN information_schema.constraint_column_usage AS ccu
                    ON ccu.constraint_name = tc.constraint_name
                    AND ccu.table_schema = tc.table_schema
                LEFT JOIN information_schema.referential_constraints AS rc
                    ON tc.constraint_name = rc.constraint_name
                    AND tc.table_schema = rc.constraint_schema
                WHERE tc.table_schema = 'public'
                AND tc.table_name = \(bind: tableName)
            """
        ).all()

        var constraints: [ConstraintSchema] = []

        for row in rows {
            guard let constraintName = try? row.decode(column: "constraint_name", as: String.self),
                let constraintType = try? row.decode(column: "constraint_type", as: String.self),
                let columnName = try? row.decode(column: "column_name", as: String.self)
            else { continue }

            switch constraintType {
            case "PRIMARY KEY":
                if !constraints.contains(where: { $0.name == constraintName }) {
                    constraints.append(
                        ConstraintSchema(
                            type: .primaryKey,
                            columns: [columnName],
                            name: constraintName
                        ))
                }

            case "FOREIGN KEY":
                guard
                    let foreignTable = try? row.decode(
                        column: "foreign_table_name", as: String.self),
                    let foreignColumn = try? row.decode(
                        column: "foreign_column_name", as: String.self)
                else { continue }

                let deleteRule = try? row.decode(column: "delete_rule", as: String?.self)
                let updateRule = try? row.decode(column: "update_rule", as: String?.self)

                let reference = ConstraintSchema.ConstraintType.ForeignKeyReference(
                    table: foreignTable,
                    column: foreignColumn,
                    onDelete: mapReferentialAction(deleteRule),
                    onUpdate: mapReferentialAction(updateRule)
                )

                constraints.append(
                    ConstraintSchema(
                        type: .foreignKey(references: reference),
                        columns: [columnName],
                        name: constraintName
                    ))

            case "UNIQUE":
                constraints.append(
                    ConstraintSchema(
                        type: .unique,
                        columns: [columnName],
                        name: constraintName
                    ))

            default:
                break
            }
        }

        return constraints
    }

    // MARK: - MySQL

    private func introspectMySQL() async throws -> DatabaseSchema {
        let dbName = try await getCurrentMySQLDatabase()

        let tableRows = try await sql.raw(
            """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = \(bind: dbName)
                AND table_type = 'BASE TABLE'
                AND table_name != '_fluent_migrations'
                ORDER BY table_name
            """
        ).all()

        var tables: [TableSchema] = []

        for row in tableRows {
            guard let tableName = try? row.decode(column: "table_name", as: String.self) else {
                continue
            }

            let columns = try await introspectMySQLColumns(tableName: tableName, database: dbName)
            let constraints = try await introspectMySQLConstraints(
                tableName: tableName, database: dbName)

            tables.append(
                TableSchema(
                    name: tableName,
                    columns: columns,
                    constraints: constraints
                ))
        }

        return DatabaseSchema(tables: tables)
    }

    private func getCurrentMySQLDatabase() async throws -> String {
        let rows = try await sql.raw("SELECT DATABASE() as db").all()
        guard let dbName = rows.first?.column("db")?.string else {
            throw IntrospectionError.cannotDetermineDatabase
        }
        return dbName
    }

    private func introspectMySQLColumns(tableName: String, database: String) async throws
        -> [ColumnSchema]
    {
        let rows = try await self.sql.raw(
            """
                SELECT
                    column_name,
                    data_type,
                    column_type,
                    character_maximum_length,
                    is_nullable,
                    column_default,
                    column_key
                FROM information_schema.columns
                WHERE table_schema = \(bind: database)
                AND table_name = \(bind: tableName)
                ORDER BY ordinal_position
            """
        ).all()

        var columns: [ColumnSchema] = []

        for row in rows {
            guard let columnName = try? row.decode(column: "column_name", as: String.self),
                let dataType = try? row.decode(column: "data_type", as: String.self)
            else { continue }

            let isNullable = (try? row.decode(column: "is_nullable", as: String.self)) == "YES"
            let maxLength = try? row.decode(column: "character_maximum_length", as: Int?.self)
            let defaultValue = try? row.decode(column: "column_default", as: String?.self)
            let columnKey = try? row.decode(column: "column_key", as: String?.self)

            let mappedType = mapMySQLType(dataType: dataType, maxLength: maxLength)

            columns.append(
                ColumnSchema(
                    name: columnName,
                    dataType: mappedType,
                    isOptional: isNullable,
                    isUnique: columnKey == "UNI",
                    defaultValue: defaultValue
                ))
        }

        return columns
    }

    private func introspectMySQLConstraints(tableName: String, database: String) async throws
        -> [ConstraintSchema]
    {
        // MySQL constraints introspection
        var constraints: [ConstraintSchema] = []

        // Get primary keys
        let pkRows = try await self.sql.raw(
            """
                SELECT column_name
                FROM information_schema.key_column_usage
                WHERE table_schema = \(bind: database)
                AND table_name = \(bind: tableName)
                AND constraint_name = 'PRIMARY'
            """
        ).all()

        if !pkRows.isEmpty {
            let columns = pkRows.compactMap { $0.column("column_name")?.string }
            if !columns.isEmpty {
                constraints.append(
                    ConstraintSchema(
                        type: .primaryKey,
                        columns: columns,
                        name: "PRIMARY"
                    ))
            }
        }

        return constraints
    }

    // MARK: - SQLite

    private func introspectSQLite() async throws -> DatabaseSchema {
        let tableRows = try await sql.raw(
            """
                SELECT name FROM sqlite_master
                WHERE type='table'
                AND name NOT LIKE 'sqlite_%'
                AND name != '_fluent_migrations'
                ORDER BY name
            """
        ).all()

        var tables: [TableSchema] = []

        for row in tableRows {
            guard let tableName = try? row.decode(column: "name", as: String.self) else { continue }

            let columns = try await introspectSQLiteColumns(tableName: tableName)
            let constraints = try await introspectSQLiteConstraints(tableName: tableName)

            tables.append(
                TableSchema(
                    name: tableName,
                    columns: columns,
                    constraints: constraints
                ))
        }

        return DatabaseSchema(tables: tables)
    }

    private func introspectSQLiteColumns(tableName: String) async throws -> [ColumnSchema] {
        let rows = try await sql.raw("PRAGMA table_info(\(bind: tableName))").all()

        var columns: [ColumnSchema] = []

        for row in rows {
            guard let columnName = try? row.decode(column: "name", as: String.self),
                let typeString = try? row.decode(column: "type", as: String.self)
            else { continue }

            let notNull = (try? row.decode(column: "notnull", as: Int.self)) == 1
            let defaultValue = try? row.decode(column: "dflt_value", as: String?.self)

            let dataType = mapSQLiteType(typeString: typeString)

            columns.append(
                ColumnSchema(
                    name: columnName,
                    dataType: dataType,
                    isOptional: !notNull,
                    isUnique: false,
                    defaultValue: defaultValue
                ))
        }

        return columns
    }

    private func introspectSQLiteConstraints(tableName: String) async throws -> [ConstraintSchema] {
        let rows = try await sql.raw("PRAGMA table_info(\(bind: tableName))").all()

        var constraints: [ConstraintSchema] = []
        var pkColumns: [String] = []

        for row in rows {
            if let columnName = try? row.decode(column: "name", as: String.self),
                let pk = try? row.decode(column: "pk", as: Int.self), pk > 0
            {
                pkColumns.append(columnName)
            }
        }

        if !pkColumns.isEmpty {
            constraints.append(
                ConstraintSchema(
                    type: .primaryKey,
                    columns: pkColumns,
                    name: nil
                ))
        }

        return constraints
    }

    // MARK: - Type Mapping

    private func mapPostgreSQLType(udtName: String, maxLength: Int?) -> ColumnSchema.DataType {
        switch udtName.lowercased() {
        case "int2": return .int16
        case "int4", "integer": return .int32
        case "int8", "bigint": return .int64
        case "bool", "boolean": return .bool
        case "varchar", "character varying":
            return .string(length: maxLength)
        case "text": return .text
        case "float4", "real": return .float
        case "float8", "double precision": return .double
        case "date": return .date
        case "timestamp", "timestamptz": return .datetime
        case "time", "timetz": return .time
        case "uuid": return .uuid
        case "bytea": return .data
        case "json", "jsonb": return .json
        default: return .custom(udtName)
        }
    }

    private func mapMySQLType(dataType: String, maxLength: Int?) -> ColumnSchema.DataType {
        switch dataType.lowercased() {
        case "tinyint": return .int8
        case "smallint": return .int16
        case "int", "integer", "mediumint": return .int32
        case "bigint": return .int64
        case "varchar", "char": return .string(length: maxLength)
        case "text", "tinytext", "mediumtext", "longtext": return .text
        case "float": return .float
        case "double": return .double
        case "date": return .date
        case "datetime", "timestamp": return .datetime
        case "time": return .time
        case "binary", "varbinary", "blob": return .data
        case "json": return .json
        default: return .custom(dataType)
        }
    }

    private func mapSQLiteType(typeString: String) -> ColumnSchema.DataType {
        let lower = typeString.lowercased()
        if lower.contains("int") {
            return .int64
        } else if lower.contains("char") || lower.contains("text") {
            return .text
        } else if lower.contains("real") || lower.contains("double") || lower.contains("float") {
            return .double
        } else if lower.contains("blob") {
            return .data
        } else {
            return .custom(typeString)
        }
    }

    private func mapReferentialAction(_ action: String?) -> ConstraintSchema.ConstraintType
        .ReferentialAction?
    {
        guard let action = action else { return nil }
        return ConstraintSchema.ConstraintType.ReferentialAction(rawValue: action)
    }
}

// MARK: - Errors

public enum IntrospectionError: Error, CustomStringConvertible {
    case unsupportedDatabase(DatabaseID)
    case cannotDetermineDatabase

    public var description: String {
        switch self {
        case .unsupportedDatabase(let id):
            return "Unsupported database type: \(id)"
        case .cannotDetermineDatabase:
            return "Cannot determine database name"
        }
    }
}

// MARK: - Database ID Extensions

extension DatabaseID {
    static let psql = DatabaseID(string: "psql")
    static let mysql = DatabaseID(string: "mysql")
    static let sqlite = DatabaseID(string: "sqlite")
}

// MARK: - Row Extensions

extension SQLRow {
    func column(_ name: String) -> DatabaseOutput? {
        try? decode(column: name, as: DatabaseOutput.self)
    }
}

public struct DatabaseOutput: Codable {
    private let value: String?

    public var string: String? { value }
    public var int: Int? { value.flatMap(Int.init) }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
