import Foundation

/// A kind's usual opening hours, used to pre-fill a new place (Lin checks
/// and edits them).
public enum TypicalOpeningHours: Equatable, Sendable {
    case alwaysOpen
    case hours(opensAt: Int, closesAt: Int)
    /// No typical hours; the place starts as "Opening hours not confirmed".
    case unknown
}

extension PlaceKind {
    /// How the kind is written, e.g. "Shopping centre".
    public var name: String {
        switch self {
        case .home: return "Home"
        case .library: return "Library"
        case .cafe: return "Café"
        case .coworkingSpace: return "Coworking space"
        case .office: return "Office"
        case .park: return "Park"
        case .beach: return "Beach"
        case .gym: return "Gym"
        case .pool: return "Pool"
        case .sportsCourt: return "Sports court"
        case .galleryOrMuseum: return "Gallery or museum"
        case .shoppingCentre: return "Shopping centre"
        case .other: return "Other"
        }
    }

    /// e.g. "libraries", for "Typical for libraries: 10 am to 8 pm".
    public var pluralName: String {
        switch self {
        case .home: return "homes"
        case .library: return "libraries"
        case .cafe: return "cafés"
        case .coworkingSpace: return "coworking spaces"
        case .office: return "offices"
        case .park: return "parks"
        case .beach: return "beaches"
        case .gym: return "gyms"
        case .pool: return "pools"
        case .sportsCourt: return "sports courts"
        case .galleryOrMuseum: return "galleries and museums"
        case .shoppingCentre: return "shopping centres"
        case .other: return "other places"
        }
    }

    public var symbolName: String {
        switch self {
        case .home: return "house"
        case .library: return "books.vertical"
        case .cafe: return "cup.and.saucer"
        case .coworkingSpace: return "person.2"
        case .office: return "building.2"
        case .park: return "tree"
        case .beach: return "beach.umbrella"
        case .gym: return "dumbbell"
        case .pool: return "figure.pool.swim"
        case .sportsCourt: return "sportscourt"
        case .galleryOrMuseum: return "building.columns"
        case .shoppingCentre: return "bag"
        case .other: return "mappin.and.ellipse"
        }
    }

    public var typicalOpeningHours: TypicalOpeningHours {
        switch self {
        case .home, .park, .beach: return .alwaysOpen
        case .library: return .hours(opensAt: 10 * 60, closesAt: 20 * 60)
        case .cafe: return .hours(opensAt: 7 * 60, closesAt: 16 * 60)
        case .coworkingSpace: return .hours(opensAt: 8 * 60, closesAt: 18 * 60)
        case .office: return .hours(opensAt: 9 * 60, closesAt: 17 * 60)
        case .gym: return .hours(opensAt: 6 * 60, closesAt: 21 * 60)
        case .pool: return .hours(opensAt: 6 * 60, closesAt: 20 * 60)
        case .sportsCourt: return .hours(opensAt: 7 * 60, closesAt: 21 * 60)
        case .galleryOrMuseum: return .hours(opensAt: 10 * 60, closesAt: 17 * 60)
        case .shoppingCentre: return .hours(opensAt: 9 * 60, closesAt: 21 * 60)
        case .other: return .unknown
        }
    }

    /// The `typicalCrowd` rules in words, e.g. "Busy weekdays 12 to 2 pm · estimate".
    public var usualBusyTimes: String {
        switch self {
        case .home: return "Quiet all day · estimate"
        case .cafe: return "Busy weekdays 12 to 2 pm · estimate"
        case .shoppingCentre: return "Busy 5 to 7 pm and Saturday mornings · estimate"
        case .gym: return "Busy weekdays 6 to 8 am and 5 to 7 pm · estimate"
        case .library, .coworkingSpace: return "Quiet mornings, moderately busy weekdays 10 am to 4 pm · estimate"
        case .park, .beach, .pool: return "Busy weekends 10 am to 4 pm · estimate"
        case .office, .sportsCourt, .galleryOrMuseum, .other: return "Moderately busy · estimate"
        }
    }
}
