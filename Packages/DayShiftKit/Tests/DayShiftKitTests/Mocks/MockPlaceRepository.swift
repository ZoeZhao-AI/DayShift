import Foundation
@testable import DayShiftKit

/// In-memory places that behave like `CoreDataPlaceRepository`, and record
/// what was saved. Set `errorToThrow` to make every call fail.
final class MockPlaceRepository: PlaceRepository {
    var errorToThrow: Error?

    private(set) var storedPlaces: [UUID: Place]
    private(set) var savedPlaces: [Place] = []

    init(places: [Place] = []) {
        storedPlaces = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
    }

    func allPlaces() async throws -> [Place] {
        try throwIfNeeded()
        return sortedByName(storedPlaces.values)
    }

    /// Ignores case and surrounding spaces.
    func place(named name: String) async throws -> Place? {
        try throwIfNeeded()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return storedPlaces.values.first {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    func save(_ place: Place) async throws {
        try throwIfNeeded()
        storedPlaces[place.id] = place
        savedPlaces.append(place)
    }

    func home() async throws -> Place? {
        try throwIfNeeded()
        return sortedByName(storedPlaces.values.filter { $0.kind == .home }).first
    }

    private func sortedByName(_ places: some Sequence<Place>) -> [Place] {
        places.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func throwIfNeeded() throws {
        if let errorToThrow { throw errorToThrow }
    }
}
