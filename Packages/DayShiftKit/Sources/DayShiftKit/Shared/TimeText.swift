import Foundation

/// Times the way DayShift writes them: "11:00 am", "6:55 am".
public enum TimeText {
    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        formatter(timeZone: calendar.timeZone).string(from: date)
    }

    /// Minutes after midnight, e.g. 360 → "6:00 am".
    public static func time(minutesAfterMidnight minutes: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60))
        return time(date, calendar: calendar)
    }

    private static func formatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter
    }
}
