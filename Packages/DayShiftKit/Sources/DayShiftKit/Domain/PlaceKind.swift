import Foundation

/// The kind of a place. Each kind gives defaults for a new place and a
/// rough crowd estimate.
public enum PlaceKind: String, CaseIterable, Codable, Hashable, Sendable {
    case home
    case library
    case cafe
    case coworkingSpace
    case office
    case park
    case beach
    case gym
    case pool
    case sportsCourt
    case galleryOrMuseum
    case shoppingCentre
    case other

    public var defaultIsIndoor: Bool {
        switch self {
        case .park, .beach, .sportsCourt:
            return false
        case .home, .library, .cafe, .coworkingSpace, .office, .gym, .pool,
             .galleryOrMuseum, .shoppingCentre, .other:
            return true
        }
    }

    public var defaultIsCooled: Bool {
        switch self {
        case .library, .cafe, .coworkingSpace, .office, .gym,
             .galleryOrMuseum, .shoppingCentre:
            return true
        case .home, .pool, .other, .park, .beach, .sportsCourt:
            return false
        }
    }

    /// A typical crowd level at this time. Always an estimate, never measured.
    /// Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday.
    public func typicalCrowd(at date: Date, calendar: Calendar = .current) -> CrowdLevel {
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7

        switch self {
        case .home:
            return .quiet
        case .cafe:
            return !isWeekend && (12..<14).contains(hour) ? .busy : .moderate
        case .shoppingCentre:
            let isEveningRush = (17..<19).contains(hour)
            let isSaturdayMorning = weekday == 7 && (9..<12).contains(hour)
            return isEveningRush || isSaturdayMorning ? .busy : .moderate
        case .gym:
            let isPeak = (6..<8).contains(hour) || (17..<19).contains(hour)
            return !isWeekend && isPeak ? .busy : .moderate
        case .library, .coworkingSpace:
            return !isWeekend && (10..<16).contains(hour) ? .moderate : .quiet
        case .park, .beach, .pool:
            return isWeekend && (10..<16).contains(hour) ? .busy : .moderate
        case .office, .sportsCourt, .galleryOrMuseum, .other:
            return .moderate
        }
    }
}
