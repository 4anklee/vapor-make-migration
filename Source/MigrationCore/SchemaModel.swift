import Foundation
import Fluent

/// Represents a database table schema
public struct TableSchema: Equatable, Codable, Sendable {
    public let name: String
    public var columns: [ColumnSchema]
    public var constraints: [ConstraintSchema]

    public init(name: String, columns: [ColumnSchema] = [], constraints: [ConstraintSchema] = []) {
        self.name = name
        self.columns = columns
        self.constraints = constraints
    }
}

/// Represents a column in a database table
public struct ColumnSchema: Equatable, Codable, Sendable {
    public let name: String
    public let dataType: DataType
    public var isOptional: Bool
    public var isUnique: Bool
    public var defaultValue: String?

    public init(
        name: String,
        dataType: DataType,
        isOptional: Bool = false,
        isUnique: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.dataType = dataType
        self.isOptional = isOptional
        self.isUnique = isUnique
        self.defaultValue = defaultValue
    }

    public enum DataType: Equatable, Codable, Sendable {
        case int
        case int8
        case int16
        case int32
        case int64
        case uint
        case uint8
        case uint16
        case uint32
        case uint64
        case bool
        case string(length: Int?)
        case text
        case double
        case float
        case date
        case datetime
        case time
        case uuid
        case data
        case json
        case custom(String)

        public var sqlType: String {
            switch self {
            case .int, .int32: return "INTEGER"
            case .int8: return "TINYINT"
            case .int16: return "SMALLINT"
            case .int64: return "BIGINT"
            case .uint, .uint32: return "INTEGER UNSIGNED"
            case .uint8: return "TINYINT UNSIGNED"
            case .uint16: return "SMALLINT UNSIGNED"
            case .uint64: return "BIGINT UNSIGNED"
            case .bool: return "BOOLEAN"
            case .string(let length):
                if let length = length {
                    return "VARCHAR(\(length))"
                }
                return "VARCHAR(255)"
            case .text: return "TEXT"
            case .double: return "DOUBLE PRECISION"
            case .float: return "REAL"
            case .date: return "DATE"
            case .datetime: return "TIMESTAMP"
            case .time: return "TIME"
            case .uuid: return "UUID"
            case .data: return "BYTEA"
            case .json: return "JSONB"
            case .custom(let type): return type
            }
        }
    }
}

/// Represents a constraint on a table
public struct ConstraintSchema: Equatable, Codable, Sendable {
    public let type: ConstraintType
    public let columns: [String]
    public let name: String?

    public init(type: ConstraintType, columns: [String], name: String? = nil) {
        self.type = type
        self.columns = columns
        self.name = name
    }

    public enum ConstraintType: Equatable, Codable, Sendable {
        case primaryKey
        case foreignKey(references: ForeignKeyReference)
        case unique
        case index

        public struct ForeignKeyReference: Equatable, Codable, Sendable {
            public let table: String
            public let column: String
            public let onDelete: ReferentialAction?
            public let onUpdate: ReferentialAction?

            public init(
                table: String,
                column: String,
                onDelete: ReferentialAction? = nil,
                onUpdate: ReferentialAction? = nil
            ) {
                self.table = table
                self.column = column
                self.onDelete = onDelete
                self.onUpdate = onUpdate
            }
        }

        public enum ReferentialAction: String, Equatable, Codable, Sendable {
            case cascade = "CASCADE"
            case restrict = "RESTRICT"
            case setNull = "SET NULL"
            case setDefault = "SET DEFAULT"
            case noAction = "NO ACTION"
        }
    }
}

/// Represents the complete database schema
public struct DatabaseSchema: Equatable, Codable, Sendable {
    public var tables: [TableSchema]

    public init(tables: [TableSchema] = []) {
        self.tables = tables
    }

    public func table(named name: String) -> TableSchema? {
        tables.first { $0.name == name }
    }
}
