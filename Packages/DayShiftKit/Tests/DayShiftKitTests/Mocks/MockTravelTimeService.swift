import Foundation
@testable import DayShiftKit

/// Scripted travel minutes between places, in the mode asked for. Records
/// every request. Unscripted trips take `defaultMinutes`; the same place is
/// always 0 minutes, as in `StraightLineTravelTimeService`.
/// `TravelTimeService` doesn't throw, so this mock can't be set to throw.
final class MockTravelTimeService: TravelTimeService {
    private struct Trip: Hashable {
        let origin: Coordinate
        let destination: Coordinate
    }

    private(set) var requests: [(origin: Coordinate, destination: Coordinate, mode: TravelMode)] = []

    private var minutesByTrip: [Trip: Int] = [:]
    private let defaultMinutes: Int

    init(defaultMinutes: Int = 10) {
        self.defaultMinutes = defaultMinutes
    }

    /// Scripts a trip in both directions.
    func setMinutes(_ minutes: Int, between first: Coordinate, and second: Coordinate) {
        minutesByTrip[Trip(origin: first, destination: second)] = minutes
        minutesByTrip[Trip(origin: second, destination: first)] = minutes
    }

    func travelEstimate(from origin: Coordinate, to destination: Coordinate, mode: TravelMode) -> TravelEstimate {
        requests.append((origin, destination, mode))
        guard origin != destination else {
            return TravelEstimate(minutes: 0, mode: mode)
        }
        let minutes = minutesByTrip[Trip(origin: origin, destination: destination)] ?? defaultMinutes
        return TravelEstimate(minutes: minutes, mode: mode)
    }
}
