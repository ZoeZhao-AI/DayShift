import Foundation

/// The domain's questions about stored plans, as pure predicates over
/// `ActivityEntity` key paths. They don't touch Core Data, so they can be
/// tested on plain objects.
enum ActivityQuery {
    /// Plans on that day that are not cancelled.
    static func plans(on day: Date, calendar: Calendar = .current) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            startsOnDay(of: day, calendar: calendar),
            NSPredicate(format: "statusRaw != %@", PlanStatus.cancelled.rawValue)
        ])
    }

    /// Today's plans that haven't started: same day, starting after `now`,
    /// and planned or adjusted.
    static func checkablePlans(on day: Date, now: Date, calendar: Calendar = .current) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            startsOnDay(of: day, calendar: calendar),
            NSPredicate(format: "start > %@", now as NSDate),
            NSPredicate(
                format: "statusRaw IN %@",
                [PlanStatus.planned.rawValue, PlanStatus.adjusted.rawValue]
            )
        ])
    }

    /// Plans that are not cancelled and overlap the interval, leaving out `ids`.
    static func plans(overlapping interval: DateInterval, excluding ids: Set<UUID>) -> NSPredicate {
        NSPredicate(
            format: "start < %@ AND end > %@ AND NOT (id IN %@) AND statusRaw != %@",
            interval.end as NSDate,
            interval.start as NSDate,
            ids.map { $0 as NSUUID },
            PlanStatus.cancelled.rawValue
        )
    }

    /// Plans on that day whose last check needs attention.
    static func plansNeedingAttention(on day: Date, calendar: Calendar = .current) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            startsOnDay(of: day, calendar: calendar),
            NSPredicate(format: "checkStatusRaw == %@", PlanCheck.Status.needsAttention.rawValue)
        ])
    }

    /// `start >= startOfDay AND start < startOfNextDay`.
    private static func startsOnDay(of day: Date, calendar: Calendar) -> NSPredicate {
        let startOfDay = calendar.startOfDay(for: day)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? startOfDay.addingTimeInterval(24 * 60 * 60)
        return NSPredicate(
            format: "start >= %@ AND start < %@",
            startOfDay as NSDate,
            startOfNextDay as NSDate
        )
    }
}
