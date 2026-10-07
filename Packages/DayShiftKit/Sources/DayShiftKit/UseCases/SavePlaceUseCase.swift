import Foundation

/// What the Place Editor collects: everything about a place except where it
/// is, which comes from its address.
public struct PlaceDraft: Equatable, Sendable {
    /// nil for a new place; the saved place's id when editing.
    public var id: UUID?
    public var name: String
    public var kind: PlaceKind
    public var address: String
    public var isIndoor: Bool
    public var isCooled: Bool
    public var uncooledHeatLimitC: Double?
    public var isAlwaysOpen: Bool
    public var openingHours: OpeningHours?

    public init(
        id: UUID? = nil,
        name: String,
        kind: PlaceKind,
        address: String,
        isIndoor: Bool,
        isCooled: Bool,
        uncooledHeatLimitC: Double?,
        isAlwaysOpen: Bool,
        openingHours: OpeningHours?
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.address = address
        self.isIndoor = isIndoor
        self.isCooled = isCooled
        self.uncooledHeatLimitC = uncooledHeatLimitC
        self.isAlwaysOpen = isAlwaysOpen
        self.openingHours = openingHours
    }
}

/// Why a place couldn't be saved (Section 3.6). Says what went wrong and what to do next.
public enum SavePlaceError: LocalizedError, Equatable {
    case duplicateName(name: String)
    case addressNotFound
    case nameIsEmpty
    case outdoorPlaceCannotBeCooled
    case heatLimitOutOfRange

    public var errorDescription: String? {
        switch self {
        case let .duplicateName(name): return "You already have a place called '\(name)'."
        case .addressNotFound: return "DayShift couldn't find that address."
        case .nameIsEmpty: return "This place needs a name."
        case .outdoorPlaceCannotBeCooled: return "An outdoor place can't be air-conditioned."
        case .heatLimitOutOfRange: return "The temperature needs to be between 20°C and 45°C."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .duplicateName: return "Use a different name, or edit the existing place."
        case .addressNotFound: return "Check the spelling, or add the suburb and postcode."
        case .nameIsEmpty: return "Enter a name, such as Home or Newtown Library."
        case .outdoorPlaceCannotBeCooled: return "Turn off Air-conditioned, or mark the place as indoor."
        case .heatLimitOutOfRange: return "Choose a temperature in this range."
        }
    }
}

/// Adds or edits one of Lin's places (Section 3.6): the name must be unique,
/// the address must resolve to coordinates, and an outdoor place can't be
/// air-conditioned.
public struct SavePlaceUseCase {
    private let places: PlaceRepository
    private let geocoder: PlaceGeocoding

    public init(places: PlaceRepository, geocoder: PlaceGeocoding) {
        self.places = places
        self.geocoder = geocoder
    }

    /// Saves the place and returns it. The name is checked before the address
    /// is looked up; an edited place whose address hasn't changed keeps its
    /// coordinates without a new lookup.
    /// - Throws: `SavePlaceError`, or `PlaceGeocodingError.unavailable` when
    ///   addresses can't be looked up at all.
    @discardableResult
    public func execute(_ draft: PlaceDraft) async throws -> Place {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = draft.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SavePlaceError.nameIsEmpty }
        guard draft.isIndoor || !draft.isCooled else { throw SavePlaceError.outdoorPlaceCannotBeCooled }

        let savedPlaces = try await places.allPlaces()
        if let clash = savedPlaces.first(where: {
            $0.id != draft.id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            throw SavePlaceError.duplicateName(name: clash.name)
        }

        let existing = draft.id.flatMap { id in savedPlaces.first { $0.id == id } }
        let location: (latitude: Double, longitude: Double, suburb: String?)
        if let existing, existing.address == address {
            location = (existing.latitude, existing.longitude, existing.suburb)
        } else {
            do {
                location = try await geocoder.coordinates(for: address)
            } catch PlaceGeocodingError.addressNotFound {
                throw SavePlaceError.addressNotFound
            }
        }

        let place: Place
        do {
            place = try Place(
                id: draft.id ?? UUID(),
                name: name,
                kind: draft.kind,
                address: address,
                latitude: location.latitude,
                longitude: location.longitude,
                suburb: location.suburb,
                isIndoor: draft.isIndoor,
                isCooled: draft.isCooled,
                uncooledHeatLimitC: draft.uncooledHeatLimitC,
                isAlwaysOpen: draft.isAlwaysOpen,
                openingHours: draft.isAlwaysOpen ? nil : draft.openingHours
            )
        } catch PlaceError.nameIsEmpty {
            throw SavePlaceError.nameIsEmpty
        } catch PlaceError.outdoorPlaceCannotBeCooled {
            throw SavePlaceError.outdoorPlaceCannotBeCooled
        } catch PlaceError.heatLimitOutOfRange {
            throw SavePlaceError.heatLimitOutOfRange
        }

        try await places.save(place)
        return place
    }
}
