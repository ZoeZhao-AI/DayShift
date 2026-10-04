import Foundation

/// Hourly conditions for one place on one day.
public struct ConditionsForecast: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let fetchedAt: Date
    /// Sorted by time.
    public let hours: [HourlyConditions]

    public init(latitude: Double, longitude: Double, fetchedAt: Date, hours: [HourlyConditions]) {
        self.latitude = latitude
        self.longitude = longitude
        self.fetchedAt = fetchedAt
        self.hours = hours.sorted { $0.time < $1.time }
    }

    /// Every hour that overlaps the interval. A 7:00–7:45 run uses the
    /// 7 am hour; 1:00–5:00 pm uses the 1, 2, 3 and 4 pm hours.
    public func conditions(during interval: DateInterval) -> [HourlyConditions] {
        hours.filter { hour in
            hour.time < interval.end && hour.time.addingTimeInterval(60 * 60) > interval.start
        }
    }
}
