import Foundation

/// A place where Lin does things: home, a library, a park.
public struct Place: Identifiable, Hashable, Sendable {
    /// Used for an indoor place without AC when no limit is given.
    public static let defaultUncooledHeatLimitC = 30.0
    public static let uncooledHeatLimitRange = 20.0...45.0

    public let id: UUID
    public let name: String
    public let kind: PlaceKind
    public let address: String
    public let latitude: Double
    public let longitude: Double
    public let suburb: String?
    public let isIndoor: Bool
    public let isCooled: Bool
    /// When it is hotter than this outside, this place is too hot.
    /// Only set for indoor places without AC.
    public let uncooledHeatLimitC: Double?
    public let isAlwaysOpen: Bool
    /// `isAlwaysOpen == false && openingHours == nil` means the hours are unknown.
    public let openingHours: OpeningHours?

    public init(
        id: UUID = UUID(),
        name: String,
        kind: PlaceKind,
        address: String,
        latitude: Double,
        longitude: Double,
        suburb: String? = nil,
        isIndoor: Bool,
        isCooled: Bool,
        uncooledHeatLimitC: Double? = nil,
        isAlwaysOpen: Bool,
        openingHours: OpeningHours? = nil
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw PlaceError.nameIsEmpty
        }
        guard isIndoor || !isCooled else {
            throw PlaceError.outdoorPlaceCannotBeCooled
        }
        if let uncooledHeatLimitC, !Self.uncooledHeatLimitRange.contains(uncooledHeatLimitC) {
            throw PlaceError.heatLimitOutOfRange
        }

        self.id = id
        self.name = trimmedName
        self.kind = kind
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.suburb = suburb
        self.isIndoor = isIndoor
        self.isCooled = isCooled
        self.uncooledHeatLimitC = isIndoor && !isCooled
            ? (uncooledHeatLimitC ?? Self.defaultUncooledHeatLimitC)
            : nil
        self.isAlwaysOpen = isAlwaysOpen
        self.openingHours = openingHours
    }
}

public enum PlaceError: Error, Equatable {
    case nameIsEmpty
    case outdoorPlaceCannotBeCooled
    case heatLimitOutOfRange
}
