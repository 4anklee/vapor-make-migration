import Foundation
import Vapor
import Fluent

/// Introspects Fluent models to build desired schema
public struct ModelIntrospector {
    public init() {}

    /// Scans models and generates expected database schema
    public func introspect(models: [any Model.Type]) throws -> DatabaseSchema {
        var tables: [TableSchema] = []

        for modelType in models {
            let table = try introspectModel(modelType)
            tables.append(table)
        }

        return DatabaseSchema(tables: tables)
    }

    private func introspectModel(_ modelType: any Model.Type) throws -> TableSchema {
        let tableName = modelType.schema

        // Create a temporary instance to introspect properties
        // This is a workaround since Swift doesn't have great reflection
        let mirror = Mirror(reflecting: modelType.init())

        var columns: [ColumnSchema] = []
        var constraints: [ConstraintSchema] = []

        // Add ID field
        columns.append(ColumnSchema(
            name: "id",
            dataType: .uuid,
            isOptional: false,
            isUnique: true
        ))

        constraints.append(ConstraintSchema(
            type: .primaryKey,
            columns: ["id"],
            name: "\(tableName)_id_pkey"
        ))

        for child in mirror.children {
            guard let label = child.label else { continue }

            // Skip special properties
            if label == "_$id" || label == "$id" {
                continue
            }

            if let field = extractFieldInfo(from: child.value, label: label) {
                columns.append(field.column)
                if let constraint = field.constraint {
                    constraints.append(constraint)
                }
            }
        }

        return TableSchema(
            name: tableName,
            columns: columns,
            constraints: constraints
        )
    }

    private func extractFieldInfo(from value: Any, label: String) -> (column: ColumnSchema, constraint: ConstraintSchema?)? {
        let mirror = Mirror(reflecting: value)

        // Try to get the field key and type
        var fieldKey: String?
        var isOptional = false
        var dataType: ColumnSchema.DataType?

        // Fluent properties have a `key` property
        for child in mirror.children {
            if child.label == "key" {
                if let key = child.value as? FieldKey {
                    fieldKey = key.description
                }
            }
        }

        // Determine data type based on the property wrapper type
        let typeString = String(describing: type(of: value))

        if typeString.contains("Field<") {
            dataType = extractDataType(from: value)
            isOptional = typeString.contains("Optional")
        } else if typeString.contains("OptionalField<") {
            dataType = extractDataType(from: value)
            isOptional = true
        } else if typeString.contains("Parent<") {
            // Foreign key relationship
            return extractParentRelation(from: value, label: label)
        } else {
            // Unknown field type
            return nil
        }

        guard let key = fieldKey, let type = dataType else {
            return nil
        }

        let column = ColumnSchema(
            name: key,
            dataType: type,
            isOptional: isOptional,
            isUnique: false
        )

        return (column, nil)
    }

    private func extractDataType(from value: Any) -> ColumnSchema.DataType? {
        let typeString = String(describing: type(of: value))

        // Extract the generic type from Field<Type>
        if let start = typeString.firstIndex(of: "<"),
           let end = typeString.firstIndex(of: ">") {
            let genericType = String(typeString[typeString.index(after: start)..<end])

            // Map Swift types to SQL types
            switch genericType {
            case "String": return .string(length: nil)
            case "Int": return .int64
            case "Int8": return .int8
            case "Int16": return .int16
            case "Int32": return .int32
            case "Int64": return .int64
            case "UInt": return .uint64
            case "UInt8": return .uint8
            case "UInt16": return .uint16
            case "UInt32": return .uint32
            case "UInt64": return .uint64
            case "Bool": return .bool
            case "Double": return .double
            case "Float": return .float
            case "Date": return .datetime
            case "UUID": return .uuid
            case "Data": return .data
            default:
                // Handle optional types
                if genericType.hasPrefix("Optional<") {
                    let innerType = genericType.dropFirst("Optional<".count).dropLast()
                    return extractDataTypeFromString(String(innerType))
                }
                return .text
            }
        }

        return nil
    }

    private func extractDataTypeFromString(_ typeString: String) -> ColumnSchema.DataType {
        switch typeString {
        case "String": return .string(length: nil)
        case "Int": return .int64
        case "Int8": return .int8
        case "Int16": return .int16
        case "Int32": return .int32
        case "Int64": return .int64
        case "UInt": return .uint64
        case "UInt8": return .uint8
        case "UInt16": return .uint16
        case "UInt32": return .uint32
        case "UInt64": return .uint64
        case "Bool": return .bool
        case "Double": return .double
        case "Float": return .float
        case "Date": return .datetime
        case "UUID": return .uuid
        case "Data": return .data
        default: return .text
        }
    }

    private func extractParentRelation(from value: Any, label: String) -> (column: ColumnSchema, constraint: ConstraintSchema?)? {
        let mirror = Mirror(reflecting: value)

        var fieldKey: String?

        for child in mirror.children {
            if child.label == "key" {
                if let key = child.value as? FieldKey {
                    fieldKey = key.description
                }
            }
        }

        guard let key = fieldKey else { return nil }

        // Foreign key column
        let column = ColumnSchema(
            name: key,
            dataType: .uuid,
            isOptional: true,
            isUnique: false
        )

        // Try to extract the related table name
        // This is challenging without more type info
        // For now, we'll create a basic foreign key constraint
        // Users might need to manually specify the target table

        return (column, nil)
    }
}

/// Protocol for registering models
public protocol MigrationModelRegistry {
    static var models: [any Model.Type] { get }
}
