import Foundation

/// Turns an address Lin types into coordinates.
public protocol PlaceGeocoding {
    /// - Throws: `PlaceGeocodingError`.
    func coordinates(for address: String) async throws -> (latitude: Double, longitude: Double, suburb: String?)
}

/// Why an address couldn't be turned into coordinates. Says what went wrong
/// and what to do next.
public enum PlaceGeocodingError: LocalizedError {
    /// No place matches the address.
    case addressNotFound
    /// The lookup itself failed, e.g. no connection.
    case unavailable(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .addressNotFound:
            return "DayShift couldn't find that address."
        case .unavailable:
            return "DayShift couldn't look up addresses right now."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .addressNotFound:
            return "Check the spelling, or add the suburb and postcode."
        case .unavailable:
            return "Check your internet connection and try again."
        }
    }
}
