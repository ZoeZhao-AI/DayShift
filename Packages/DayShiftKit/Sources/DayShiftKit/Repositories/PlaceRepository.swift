import Foundation

/// Reads and saves Lin's places.
public protocol PlaceRepository {
    func allPlaces() async throws -> [Place]

    func place(named name: String) async throws -> Place?

    /// Adds the place, or replaces the saved place with the same id.
    func save(_ place: Place) async throws

    /// The place of kind `.home`, if Lin has saved one.
    func home() async throws -> Place?
}
