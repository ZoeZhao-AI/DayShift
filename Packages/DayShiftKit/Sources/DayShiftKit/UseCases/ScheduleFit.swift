import Foundation

/// Whether a plan fits the day around other plans (Section 2.9): no overlaps,
/// and enough time to get there from the plan before and on to the plan
/// after. Shared by SuggestAlternativesUseCase and AcceptAlternativeUseCase.
struct ScheduleFit {
    let travelTimes: TravelTimeService
    let calendar: Calendar

    /// The conflicts between `plan` and `others`, using travel from the plan
    /// before (or Home) and to the plan after.
    func conflicts(for plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> [ScheduleConflict] {
        DaySchedule(date: plan.start, plans: others).conflicts(
            for: plan.interval,
            travelBefore: travelMinutes(before: plan, among: others, home: home, preferences: preferences),
            travelAfter: travelMinutes(after: plan, among: others, home: home, preferences: preferences),
            excluding: [plan.id],
            buffer: preferences.minimumBufferMinutes
        )
    }

    /// The other plans that stop `plan` fitting.
    func blockingPlans(for plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> [PlannedActivity] {
        let ids = Set(conflicts(for: plan, among: others, home: home, preferences: preferences).map(\.planID))
        return others.filter { ids.contains($0.id) }
    }

    func isWithinPlanningHours(_ interval: DateInterval, preferences: ComfortPreferences) -> Bool {
        let startOfDay = calendar.startOfDay(for: interval.start)
        let startMinute = calendar.dateComponents([.minute], from: startOfDay, to: interval.start).minute ?? 0
        let endMinute = calendar.dateComponents([.minute], from: startOfDay, to: interval.end).minute ?? 0
        return startMinute >= preferences.earliestPlanTime && endMinute <= preferences.latestPlanTime
    }

    private func travelMinutes(before plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> Int {
        let previous = others.filter { $0.end <= plan.start }.max { $0.end < $1.end }
        return travelMinutes(from: previous?.place ?? home, to: plan.place, preferences: preferences)
    }

    private func travelMinutes(after plan: PlannedActivity, among others: [PlannedActivity], home: Place?, preferences: ComfortPreferences) -> Int {
        let next = others.filter { $0.start >= plan.end }.min { $0.start < $1.start }
        return travelMinutes(from: plan.place ?? home, to: next?.place, preferences: preferences)
    }

    private func travelMinutes(from origin: Place?, to destination: Place?, preferences: ComfortPreferences) -> Int {
        guard let origin, let destination else { return 0 }
        return travelTimes.travelEstimate(from: origin.coordinate, to: destination.coordinate, mode: preferences.travelMode).minutes
    }
}

extension ScheduleConflict {
    /// The other plan in the conflict.
    var planID: UUID {
        switch self {
        case let .overlaps(planID), let .notEnoughGap(planID, _, _): return planID
        }
    }
}
