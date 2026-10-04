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

    /// Drops ":00" on the hour, as in "Smoke until 10 am" or "Open until 6 pm".
    public static func shortTime(_ date: Date, calendar: Calendar = .current) -> String {
        let full = time(date, calendar: calendar)
        return full.replacingOccurrences(of: ":00 ", with: " ")
    }

    /// Minutes after midnight, e.g. 1080 → "6 pm".
    public static func shortTime(minutesAfterMidnight minutes: Int) -> String {
        time(minutesAfterMidnight: minutes).replacingOccurrences(of: ":00 ", with: " ")
    }

    /// A plan's times, e.g. "7:00–7:45 am" or "11:30 am–1:00 pm".
    public static func range(_ start: Date, _ end: Date, calendar: Calendar = .current) -> String {
        let startText = time(start, calendar: calendar)
        let endText = time(end, calendar: calendar)
        let startHalf = calendar.component(.hour, from: start) < 12
        let endHalf = calendar.component(.hour, from: end) < 12
        guard startHalf == endHalf else { return "\(startText)–\(endText)" }
        let startWithoutHalf = startText.replacingOccurrences(of: startHalf ? " am" : " pm", with: "")
        return "\(startWithoutHalf)–\(endText)"
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
