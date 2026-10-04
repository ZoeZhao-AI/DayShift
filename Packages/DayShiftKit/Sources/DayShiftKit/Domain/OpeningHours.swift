import Foundation

/// Daily opening hours of a place, in minutes after midnight.
/// Weekdays use `Calendar` numbering: 1 = Sunday … 7 = Saturday.
public struct OpeningHours: Hashable, Sendable {
    public let opensAt: Int
    public let closesAt: Int
    public let closedWeekdays: Set<Int>

    public init(opensAt: Int, closesAt: Int, closedWeekdays: Set<Int>) throws {
        guard closesAt > opensAt else {
            throw OpeningHoursError.closesBeforeOpening
        }
        self.opensAt = opensAt
        self.closesAt = closesAt
        self.closedWeekdays = closedWeekdays
    }

    /// True when the place is open from the start to the end of the interval.
    /// An interval that runs past midnight is never open throughout.
    public func isOpen(throughout interval: DateInterval, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: interval.start)
        guard !closedWeekdays.contains(weekday) else { return false }

        let startOfDay = calendar.startOfDay(for: interval.start)
        let startMinute = minutes(from: startOfDay, to: interval.start, calendar: calendar)
        let endMinute = minutes(from: startOfDay, to: interval.end, calendar: calendar)
        return startMinute >= opensAt && endMinute <= closesAt
    }

    private func minutes(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.minute], from: start, to: end).minute ?? 0
    }
}

public enum OpeningHoursError: Error, Equatable {
    case closesBeforeOpening
}
