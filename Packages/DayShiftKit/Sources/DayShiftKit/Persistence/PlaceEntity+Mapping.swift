import CoreData
import Foundation

extension PlaceEntity {
    private static let entityName = "PlaceEntity"

    /// The stored place. Runs the same checks as `Place.init`.
    func place() throws -> Place {
        let openingHours: OpeningHours?
        switch (opensAt, closesAt) {
        case let (opensAt?, closesAt?):
            openingHours = try OpeningHours(
                opensAt: opensAt.intValue,
                closesAt: closesAt.intValue,
                closedWeekdays: PersistenceMapping.weekdays(
                    from: closedWeekdays, entity: Self.entityName, attribute: "closedWeekdays"
                )
            )
        case (nil, nil):
            openingHours = nil
        default:
            throw PersistenceMappingError.invalidValue(entity: Self.entityName, attribute: "opensAt/closesAt")
        }

        return try Place(
            id: id,
            name: name,
            kind: PersistenceMapping.decodeRaw(
                kindRaw, as: PlaceKind.self, entity: Self.entityName, attribute: "kindRaw"
            ),
            address: address,
            latitude: latitude,
            longitude: longitude,
            suburb: suburb,
            isIndoor: isIndoor,
            isCooled: isCooled,
            uncooledHeatLimitC: uncooledHeatLimitC?.doubleValue,
            isAlwaysOpen: isAlwaysOpen,
            openingHours: openingHours
        )
    }

    func update(from place: Place) throws {
        id = place.id
        name = place.name
        kindRaw = place.kind.rawValue
        address = place.address
        suburb = place.suburb
        latitude = place.latitude
        longitude = place.longitude
        isIndoor = place.isIndoor
        isCooled = place.isCooled
        uncooledHeatLimitC = place.uncooledHeatLimitC.map { NSNumber(value: $0) }
        isAlwaysOpen = place.isAlwaysOpen
        if let hours = place.openingHours {
            opensAt = NSNumber(value: try PersistenceMapping.int16(
                hours.opensAt, entity: Self.entityName, attribute: "opensAt"
            ))
            closesAt = NSNumber(value: try PersistenceMapping.int16(
                hours.closesAt, entity: Self.entityName, attribute: "closesAt"
            ))
            closedWeekdays = PersistenceMapping.joinedWeekdays(hours.closedWeekdays)
        } else {
            opensAt = nil
            closesAt = nil
            closedWeekdays = ""
        }
    }
}
