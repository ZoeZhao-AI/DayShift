import DayShiftKit
import Foundation
import Observation

/// Lin's saved places (Section 7.3, MyPlaces). The list is read through
/// PlaceRepository (1.3); saving goes through SavePlaceUseCase in the editor.
@MainActor
@Observable
final class MyPlacesViewModel {
    struct PlaceRow: Identifiable, Equatable {
        let id: UUID
        let name: String
        let symbolName: String
        /// e.g. "Library · Newtown".
        let detail: String
        /// e.g. "Indoor, air-conditioned".
        let comfort: String
    }

    private(set) var rows: [PlaceRow] = []
    private(set) var error: ErrorMessage?
    private(set) var hasLoaded = false
    private var placesByID: [UUID: Place] = [:]

    private let places: PlaceRepository
    private let checkUpcomingPlans: CheckUpcomingPlansUseCase

    init(places: PlaceRepository, checkUpcomingPlans: CheckUpcomingPlansUseCase) {
        self.places = places
        self.checkUpcomingPlans = checkUpcomingPlans
    }

    func load() async {
        do {
            let saved = try await places.allPlaces()
            placesByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            rows = saved.map(Self.row(for:))
            error = nil
        } catch {
            self.error = ErrorMessage(error)
        }
        hasLoaded = true
    }

    func place(withID id: UUID) -> Place? {
        placesByID[id]
    }

    /// After a place is saved: show it, and check today's plans again, since
    /// AC, the heat limit or opening hours can change their statuses. A check
    /// that can't run now runs again when the app becomes active.
    func placeWasSaved(now: Date = Date()) async {
        await load()
        _ = try? await checkUpcomingPlans.execute(now: now)
    }

    private static func row(for place: Place) -> PlaceRow {
        let comfort: String
        if !place.isIndoor {
            comfort = "Outdoor"
        } else if place.isCooled {
            comfort = "Indoor, air-conditioned"
        } else if let limit = place.uncooledHeatLimitC {
            comfort = "Indoor, no AC · too hot above \(Int(limit.rounded()))°C outside"
        } else {
            comfort = "Indoor, no AC"
        }
        return PlaceRow(
            id: place.id,
            name: place.name,
            symbolName: place.kind.symbolName,
            detail: [place.kind.name, place.suburb].compactMap { $0 }.joined(separator: " · "),
            comfort: comfort
        )
    }
}
