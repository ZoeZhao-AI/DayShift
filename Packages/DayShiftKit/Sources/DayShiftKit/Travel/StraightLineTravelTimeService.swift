import Foundation

/// Travel time from straight-line distance (Section 5.2): haversine distance
/// × 1.3 for roads, at a typical speed per mode, rounded up to whole minutes.
/// Public transport adds 10 minutes of waiting. The same place is 0 minutes.
public struct StraightLineTravelTimeService: TravelTimeService {
    static let earthRadiusKm = 6371.0
    static let roadFactor = 1.3
    static let publicTransportWaitingMinutes = 10

    public init() {}

    public func travelEstimate(from origin: Coordinate, to destination: Coordinate, mode: TravelMode) -> TravelEstimate {
        guard origin != destination else {
            return TravelEstimate(minutes: 0, mode: mode)
        }
        let roadKm = Self.straightLineKm(from: origin, to: destination) * Self.roadFactor
        let travelMinutes = Int((roadKm / Self.speedKmh(for: mode) * 60).rounded(.up))
        let waitingMinutes = mode == .publicTransport ? Self.publicTransportWaitingMinutes : 0
        return TravelEstimate(minutes: travelMinutes + waitingMinutes, mode: mode)
    }

    static func speedKmh(for mode: TravelMode) -> Double {
        switch mode {
        case .walking: return 4.5
        case .publicTransport: return 20
        case .driving: return 30
        }
    }

    /// Haversine distance in kilometres.
    static func straightLineKm(from origin: Coordinate, to destination: Coordinate) -> Double {
        let lat1 = origin.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (destination.longitude - origin.longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadiusKm * atan2(sqrt(a), sqrt(1 - a))
    }
}
