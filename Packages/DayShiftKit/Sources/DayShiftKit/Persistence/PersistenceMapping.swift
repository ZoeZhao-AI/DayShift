import Foundation

/// A stored value that can't be turned into a domain type.
enum PersistenceMappingError: Error, Equatable {
    case invalidValue(entity: String, attribute: String)
    case missingRelationship(entity: String, relationship: String)
    case mismatchedRelationship(entity: String, relationship: String)
}

/// Helpers shared by the entity mappings.
enum PersistenceMapping {
    static func decodeRaw<Value: RawRepresentable>(
        _ raw: String,
        as type: Value.Type,
        entity: String,
        attribute: String
    ) throws -> Value where Value.RawValue == String {
        guard let value = Value(rawValue: raw) else {
            throw PersistenceMappingError.invalidValue(entity: entity, attribute: attribute)
        }
        return value
    }

    /// Converts without trapping: a value that doesn't fit in Int16 throws.
    static func int16(_ value: Int, entity: String, attribute: String) throws -> Int16 {
        guard let converted = Int16(exactly: value) else {
            throw PersistenceMappingError.invalidValue(entity: entity, attribute: attribute)
        }
        return converted
    }

    /// "1,7" ↔ [1, 7]; "" ↔ [].
    static func joinedWeekdays(_ weekdays: Set<Int>) -> String {
        weekdays.sorted().map(String.init).joined(separator: ",")
    }

    static func weekdays(from joined: String, entity: String, attribute: String) throws -> Set<Int> {
        guard !joined.isEmpty else { return [] }
        return try Set(joined.split(separator: ",").map { part in
            guard let weekday = Int(part) else {
                throw PersistenceMappingError.invalidValue(entity: entity, attribute: attribute)
            }
            return weekday
        })
    }

    /// "heat,poorAirQuality" ↔ ["heat", "poorAirQuality"]; nil ↔ [].
    static func joinedKeys(_ keys: Set<String>) -> String? {
        keys.isEmpty ? nil : keys.sorted().joined(separator: ",")
    }

    static func keys(from joined: String?) -> Set<String> {
        guard let joined, !joined.isEmpty else { return [] }
        return Set(joined.split(separator: ",").map(String.init))
    }
}
