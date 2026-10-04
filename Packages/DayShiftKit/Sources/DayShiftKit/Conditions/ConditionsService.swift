import Foundation

/// Weather and air quality by the hour.
public protocol ConditionsService {
    /// Hourly conditions on `day` for each coordinate, keyed by the
    /// coordinates exactly as they were passed in.
    func forecast(for coordinates: [Coordinate], on day: Date) async throws -> [Coordinate: ConditionsForecast]
}
