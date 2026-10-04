import DayShiftKit

/// Lin's four places from the prototype, for the temporary "Add sample places"
/// button on Today. Step 10 removes this with My Places and the Place Editor.
/// Coordinates are approximate.
enum SamplePlaces {
    static func all() throws -> [Place] {
        [
            try Place(
                name: "Home", kind: .home, address: "Enmore NSW 2042",
                latitude: -33.9000, longitude: 151.1740, suburb: "Enmore",
                isIndoor: true, isCooled: false, uncooledHeatLimitC: 30,
                isAlwaysOpen: true
            ),
            try Place(
                name: "Newtown Library", kind: .library, address: "8–10 Brown St, Newtown NSW 2042",
                latitude: -33.8975, longitude: 151.1790, suburb: "Newtown",
                isIndoor: true, isCooled: true,
                isAlwaysOpen: false,
                openingHours: OpeningHours(opensAt: 9 * 60, closesAt: 18 * 60, closedWeekdays: [])
            ),
            try Place(
                name: "Enmore Park", kind: .park, address: "Enmore Rd, Marrickville NSW 2204",
                latitude: -33.9035, longitude: 151.1685, suburb: "Marrickville",
                isIndoor: false, isCooled: false,
                isAlwaysOpen: true
            ),
            try Place(
                name: "Marrickville Metro", kind: .shoppingCentre, address: "34 Victoria Rd, Marrickville NSW 2204",
                latitude: -33.9110, longitude: 151.1650, suburb: "Marrickville",
                isIndoor: true, isCooled: true,
                isAlwaysOpen: false,
                openingHours: OpeningHours(opensAt: 7 * 60, closesAt: 21 * 60, closedWeekdays: [])
            )
        ]
    }
}
