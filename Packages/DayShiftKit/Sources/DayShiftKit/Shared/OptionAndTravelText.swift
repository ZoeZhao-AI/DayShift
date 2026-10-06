import Foundation

extension TravelEstimate {
    /// e.g. "5 min walk", "12 min by public transport", "8 min drive".
    public var text: String {
        switch mode {
        case .walking: return "\(minutes) min walk"
        case .publicTransport: return "\(minutes) min by public transport"
        case .driving: return "\(minutes) min drive"
        }
    }
}

extension AlternativePlan {
    /// The option as its card and notification show it:
    /// "Move to 5:30 pm · Enmore Park" or "Move to Newtown Library · 1:00 to 5:00 pm".
    public func title(for plan: PlannedActivity, calendar: Calendar) -> String {
        switch adjustment {
        case let .shiftTime(newStart):
            return "Move to \(TimeText.time(newStart, calendar: calendar)) · \(plan.place?.name ?? "Online")"
        case let .changePlace(place):
            let times = TimeText.range(plan.start, plan.end, calendar: calendar).replacingOccurrences(of: "–", with: " to ")
            return "Move to \(place.name) · \(times)"
        }
    }
}
