import Foundation
@testable import DayShiftKit

/// Scripted hourly conditions per place. Like `OpenMeteoConditionsService`, it
/// returns only the requested day's hours, keyed by the coordinates as passed in,
/// and leaves out coordinates it has no hours for. Records every request.
/// Set `errorToThrow` to make every call fail.
final class MockConditionsService: ConditionsService {
    var errorToThrow: Error?
    private(set) var requests: [(coordinates: [Coordinate], day: Date)] = []

    private var hoursByCoordinate: [Coordinate: [HourlyConditions]]
    private let fetchedAt: Date
    private let calendar: Calendar

    init(hoursByCoordinate: [Coordinate: [HourlyConditions]] = [:], fetchedAt: Date, calendar: Calendar) {
        self.hoursByCoordinate = hoursByCoordinate
        self.fetchedAt = fetchedAt
        self.calendar = calendar
    }

    /// Lin's Thursday: the same smoky, hot, high-UV day at every one of her places.
    convenience init(_ day: LinsThursday) throws {
        let hours = try day.hourlyConditions()
        self.init(
            hoursByCoordinate: Dictionary(uniqueKeysWithValues: day.places.map { ($0.coordinate, hours) }),
            fetchedAt: day.now,
            calendar: day.calendar
        )
    }

    /// Replaces the scripted hours at one place, e.g. to make the library hot.
    func setHours(_ hours: [HourlyConditions], at coordinate: Coordinate) {
        hoursByCoordinate[coordinate] = hours
    }

    func forecast(for coordinates: [Coordinate], on day: Date) async throws -> [Coordinate: ConditionsForecast] {
        requests.append((coordinates, day))
        if let errorToThrow { throw errorToThrow }

        var result: [Coordinate: ConditionsForecast] = [:]
        for coordinate in coordinates {
            guard let hours = hoursByCoordinate[coordinate] else { continue }
            result[coordinate] = ConditionsForecast(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fetchedAt: fetchedAt,
                hours: hours.filter { calendar.isDate($0.time, inSameDayAs: day) }
            )
        }
        return result
    }
}
