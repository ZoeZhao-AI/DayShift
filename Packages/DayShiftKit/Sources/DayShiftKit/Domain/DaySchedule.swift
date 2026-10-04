import Foundation

/// Lin's plans for one day. Travel minutes are worked out by the use case
/// beforehand, so this type stays pure.
public struct DaySchedule: Hashable, Sendable {
    public let date: Date
    /// Plans that are not cancelled, sorted by start.
    public let plans: [PlannedActivity]

    public init(date: Date, plans: [PlannedActivity]) {
        self.date = date
        self.plans = plans
            .filter { $0.status != .cancelled }
            .sorted { $0.start < $1.start }
    }

    /// The time needed between two plans: the buffer, or longer if travel takes longer.
    public static func requiredGap(travelMinutes: Int, buffer: Int) -> Int {
        max(buffer, travelMinutes)
    }

    /// Conflicts for a plan at `interval`, compared with every other plan that day.
    /// - Parameters:
    ///   - travelBefore: minutes to get here from the plan just before.
    ///   - travelAfter: minutes to get from here to the plan just after.
    ///   - excluding: plans to ignore, such as the plan being moved.
    public func conflicts(
        for interval: DateInterval,
        travelBefore: Int,
        travelAfter: Int,
        excluding: Set<UUID>,
        buffer: Int
    ) -> [ScheduleConflict] {
        let others = plans.filter { !excluding.contains($0.id) }

        var conflicts: [ScheduleConflict] = others
            .filter { $0.start < interval.end && $0.end > interval.start }
            .map { .overlaps(planID: $0.id) }

        let previous = others
            .filter { $0.end <= interval.start }
            .max { $0.end < $1.end }
        if let previous {
            let available = minutes(from: previous.end, to: interval.start)
            let required = Self.requiredGap(travelMinutes: travelBefore, buffer: buffer)
            if available < required {
                conflicts.append(.notEnoughGap(planID: previous.id, available: available, required: required))
            }
        }

        let next = others
            .filter { $0.start >= interval.end }
            .min { $0.start < $1.start }
        if let next {
            let available = minutes(from: interval.end, to: next.start)
            let required = Self.requiredGap(travelMinutes: travelAfter, buffer: buffer)
            if available < required {
                conflicts.append(.notEnoughGap(planID: next.id, available: available, required: required))
            }
        }

        return conflicts
    }

    /// Whole minutes between two times, rounded down.
    private func minutes(from start: Date, to end: Date) -> Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}
