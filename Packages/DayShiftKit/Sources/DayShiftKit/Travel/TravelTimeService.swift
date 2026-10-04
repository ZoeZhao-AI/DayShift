import Foundation

/// How long it takes to get from one place to another.
public protocol TravelTimeService {
    func travelEstimate(from origin: Coordinate, to destination: Coordinate, mode: TravelMode) -> TravelEstimate
}
