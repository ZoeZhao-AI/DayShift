import Foundation

/// Why a plan couldn't be saved (Section 3.1). Says what went wrong and what to do next.
public enum PlanActivityError: LocalizedError, Equatable {
    case startsInThePast
    case outsidePlanningHours(earliestMinutes: Int, latestMinutes: Int)
    case overlaps(title: String, time: Date)
    /// Not enough time to get here from the plan before.
    case notEnoughTimeToGetThere(title: String, minutes: Int)
    /// Not enough time to get from here to the plan after.
    case notEnoughTimeForNextPlan(title: String, minutes: Int)
    case placeClosed(name: String)
    case onlineNotAvailable(activityName: String)

    public var errorDescription: String? {
        switch self {
        case .startsInThePast:
            return "This plan starts in the past."
        case let .outsidePlanningHours(earliest, latest):
            return "This plan is outside your planning hours (\(TimeText.time(minutesAfterMidnight: earliest)) to \(TimeText.time(minutesAfterMidnight: latest)))."
        case let .overlaps(title, time):
            return "This plan overlaps with \(title) at \(TimeText.time(time))."
        case let .notEnoughTimeToGetThere(title, minutes):
            return "You need \(minutes) minutes to get here after \(title)."
        case let .notEnoughTimeForNextPlan(title, minutes):
            return "You need \(minutes) minutes to get to \(title) after this plan."
        case let .placeClosed(name):
            return "\(name) is closed for part of this plan."
        case let .onlineNotAvailable(activityName):
            return "\(activityName) can't be done online."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .startsInThePast:
            return "Choose a start time later than now."
        case .outsidePlanningHours:
            return "Choose a time within these hours, or change your planning hours in Settings."
        case .overlaps:
            return "Choose another time, or shorten one of the plans."
        case .notEnoughTimeToGetThere:
            return "Start later, or choose a place closer to your previous plan."
        case .notEnoughTimeForNextPlan:
            return "Start earlier, or choose a place closer to your next plan."
        case .placeClosed:
            return "Check the opening hours in My Places, or choose another place."
        case .onlineNotAvailable:
            return "Choose a place for this plan."
        }
    }
}

/// Creates or edits a plan (Section 3.1).
public struct PlanActivityUseCase {
    private let activities: ActivityRepository
    private let places: PlaceRepository
    private let preferences: PreferencesRepository
    private let travelTimes: TravelTimeService
    private let planChecker: PlanChecking
    private let widget: WidgetRefreshing
    private let notifications: NotificationScheduling
    private let calendar: Calendar

    public init(
        activities: ActivityRepository,
        places: PlaceRepository,
        preferences: PreferencesRepository,
        travelTimes: TravelTimeService,
        planChecker: PlanChecking,
        widget: WidgetRefreshing,
        notifications: NotificationScheduling,
        calendar: Calendar = .current
    ) {
        self.activities = activities
        self.places = places
        self.preferences = preferences
        self.travelTimes = travelTimes
        self.planChecker = planChecker
        self.widget = widget
        self.notifications = notifications
        self.calendar = calendar
    }

    /// Checks the rules, saves the plan, then checks it, refreshes the widget
    /// and schedules its leave reminder. A failed check or reminder doesn't
    /// undo the save: the plan is saved, and the check runs again later.
    public func execute(_ plan: PlannedActivity, now: Date) async throws {
        let preferences = try await preferences.load()

        guard plan.start >= now else {
            throw PlanActivityError.startsInThePast
        }
        guard isWithinPlanningHours(plan, preferences: preferences) else {
            throw PlanActivityError.outsidePlanningHours(
                earliestMinutes: preferences.earliestPlanTime,
                latestMinutes: preferences.latestPlanTime
            )
        }
        let activityType = ActivityCatalogue.type(withID: plan.typeID)
        if plan.mode == .online, activityType?.canBeOnline != true {
            throw PlanActivityError.onlineNotAvailable(activityName: activityType?.name ?? plan.title)
        }
        if let place = plan.place, !place.isAlwaysOpen, let hours = place.openingHours,
           !hours.isOpen(throughout: plan.interval, calendar: calendar) {
            throw PlanActivityError.placeClosed(name: place.name)
        }

        let otherPlans = try await activities.plans(on: plan.start).filter { $0.id != plan.id }
        let home = try await places.home()
        let previous = otherPlans.filter { $0.end <= plan.start }.max { $0.end < $1.end }
        let next = otherPlans.filter { $0.start >= plan.end }.min { $0.start < $1.start }
        let travelBefore = travel(from: previous?.place ?? home, to: plan.place, preferences: preferences)
        let travelAfter = travel(from: plan.place ?? home, to: next.flatMap { $0.place }, preferences: preferences)

        let conflicts = DaySchedule(date: plan.start, plans: otherPlans).conflicts(
            for: plan.interval,
            travelBefore: travelBefore?.minutes ?? 0,
            travelAfter: travelAfter?.minutes ?? 0,
            excluding: [plan.id],
            buffer: preferences.minimumBufferMinutes
        )
        if let conflict = conflicts.first(where: { if case .overlaps = $0 { return true } else { return false } })
            ?? conflicts.first {
            throw error(for: conflict, otherPlans: otherPlans, previousID: previous?.id)
        }

        try await activities.save(plan)

        let check = try? await planChecker.checkPlan(plan, now: now)
        widget.reload()
        await notifications.removeNotifications(forPlan: plan.id)
        if let place = plan.place, let travelBefore, travelBefore.minutes > 0 {
            let leaveBy = plan.start.addingTimeInterval(-TimeInterval(travelBefore.minutes * 60))
            let fireAt = leaveBy.addingTimeInterval(-TimeInterval(preferences.leaveReminderMinutes * 60))
            if fireAt > now {
                try? await notifications.scheduleLeaveReminder(LeaveReminder(
                    planID: plan.id,
                    planTitle: plan.title,
                    placeName: place.name,
                    travel: travelBefore,
                    leaveBy: leaveBy,
                    fireAt: fireAt,
                    findings: check?.findings ?? []
                ))
            }
        }
    }

    /// The whole plan must fall between the earliest and latest planning times that day.
    private func isWithinPlanningHours(_ plan: PlannedActivity, preferences: ComfortPreferences) -> Bool {
        let startOfDay = calendar.startOfDay(for: plan.start)
        let startMinute = calendar.dateComponents([.minute], from: startOfDay, to: plan.start).minute ?? 0
        let endMinute = calendar.dateComponents([.minute], from: startOfDay, to: plan.end).minute ?? 0
        return startMinute >= preferences.earliestPlanTime && endMinute <= preferences.latestPlanTime
    }

    /// Travel between two places; nil when either end is online (no travel).
    private func travel(from origin: Place?, to destination: Place?, preferences: ComfortPreferences) -> TravelEstimate? {
        guard let origin, let destination else { return nil }
        return travelTimes.travelEstimate(
            from: origin.coordinate,
            to: destination.coordinate,
            mode: preferences.travelMode
        )
    }

    private func error(for conflict: ScheduleConflict, otherPlans: [PlannedActivity], previousID: UUID?) -> PlanActivityError {
        switch conflict {
        case let .overlaps(planID):
            let other = otherPlans.first { $0.id == planID }
            return .overlaps(title: other?.title ?? "another plan", time: other?.start ?? Date())
        case let .notEnoughGap(planID, _, required):
            let title = otherPlans.first { $0.id == planID }?.title ?? "another plan"
            return planID == previousID
                ? .notEnoughTimeToGetThere(title: title, minutes: required)
                : .notEnoughTimeForNextPlan(title: title, minutes: required)
        }
    }
}
