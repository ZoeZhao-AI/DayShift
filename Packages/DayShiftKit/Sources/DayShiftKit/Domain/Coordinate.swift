import Foundation

/// A point on the map, in degrees.
public struct Coordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

extension Place {
    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}
