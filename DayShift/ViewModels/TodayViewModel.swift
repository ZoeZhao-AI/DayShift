import DayShiftKit
import Foundation
import Observation

/// Today's plans with their latest check (Section 7.3). Runs the check when
/// the app becomes active; if conditions are unavailable, shows the last
/// saved checks with when they were made.
@MainActor
@Observable
final class TodayViewModel {
    struct PlanRow: Identifiable, Equatable {
        let id: UUID
        let symbolName: String
        let activityName: String
        /// e.g. "7:00–7:45 am".
        let timeText: String
        let title: String
        /// e.g. "Enmore Park · Leave by 6:55 am", or "Online".
        let detail: String
        let status: PlanDisplayStatus
        /// The first problem, shown when the plan needs attention.
        let reason: String?
        let isMoved: Bool
    }

    /// One day under "Coming up", e.g. "Tomorrow" or "Tuesday 6 Oct".
    struct DayGroup: Identifiable, Equatable {
        let id: Date
        let title: String
        let rows: [PlanRow]
    }

    /// How many days after today "Coming up" covers (7.4).
    static let comingUpDays = 7

    private(set) var weekday = ""
    private(set) var rows: [PlanRow] = []
    private(set) var comingUp: [DayGroup] = []
    private(set) var footer: String?
    private(set) var problemBanner: ErrorMessage?
    private(set) var alertsAreOff = false
    private(set) var showsAddSamplePlaces = false
    private(set) var hasLoaded = false
    /// A short confirmation at the bottom of Today, e.g. "Saved for Monday 5 Oct."
    /// after saving a plan for another day, or "Your run is now at 5:30 pm."
    private(set) var toast: String?
    private var plansByID: [UUID: PlannedActivity] = [:]

    private let checkUpcomingPlans: CheckUpcomingPlansUseCase
    private let activities: ActivityRepository
    private let places: PlaceRepository
    private let alertsStatus: AlertsStatusChecking
    private let calendar: Calendar
    private var isRefreshing = false

    init(
        checkUpcomingPlans: CheckUpcomingPlansUseCase,
        activities: ActivityRepository,
        places: PlaceRepository,
        alertsStatus: AlertsStatusChecking,
        calendar: Calendar
    ) {
        self.checkUpcomingPlans = checkUpcomingPlans
        self.activities = activities
        self.places = places
        self.alertsStatus = alertsStatus
        self.calendar = calendar
    }

    /// Checks today's upcoming plans, then shows every plan today with its
    /// latest saved check.
    func refresh(now: Date = Date()) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        weekday = now.formatted(.dateTime.weekday(.wide))
        var checkError: Error?
        do {
            _ = try await checkUpcomingPlans.execute(now: now)
        } catch {
            checkError = error
        }
        await showPlans(now: now, checkError: checkError)
        alertsAreOff = await alertsStatus.alertsAreOff()
        showsAddSamplePlaces = await hasMissingSamplePlaces()
        hasLoaded = true
    }

    /// Temporary until My Places (Step 10): saves Lin's four places that
    /// aren't saved yet, then refreshes. A saving error is shown after the
    /// refresh, so the refresh can't clear it.
    func addSamplePlaces() async {
        var saveError: Error?
        do {
            for place in try SamplePlaces.all() where try await places.place(named: place.name) == nil {
                try await places.save(place)
            }
        } catch {
            saveError = error
        }
        await refresh()
        if let saveError {
            problemBanner = ErrorMessage(saveError)
        }
    }

    private func showPlans(now: Date, checkError: Error?) async {
        do {
            var rows: [PlanRow] = []
            var lastCheckedAt: Date?
            let plans = try await activities.plans(on: now)
            for plan in plans {
                let check = try await activities.check(for: plan.id)
                if let checkedAt = check?.checkedAt, checkedAt > (lastCheckedAt ?? .distantPast) {
                    lastCheckedAt = checkedAt
                }
                rows.append(row(for: plan, check: check, now: now))
            }
            self.rows = rows

            // Later days aren't checked yet, so their checks aren't read.
            var groups: [DayGroup] = []
            var laterPlans: [PlannedActivity] = []
            let startOfToday = calendar.startOfDay(for: now)
            for offset in 1...Self.comingUpDays {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
                let dayPlans = try await activities.plans(on: day)
                guard !dayPlans.isEmpty else { continue }
                laterPlans += dayPlans
                groups.append(DayGroup(
                    id: day,
                    title: offset == 1 ? "Tomorrow" : TimeText.day(day, calendar: calendar),
                    rows: dayPlans.map { row(for: $0, check: nil, now: now) }
                ))
            }
            comingUp = groups
            plansByID = Dictionary(uniqueKeysWithValues: (plans + laterPlans).map { ($0.id, $0) })

            if let checkError {
                problemBanner = ErrorMessage(checkError)
                footer = lastCheckedAt.map { "Statuses from the last check at \(TimeText.time($0, calendar: calendar))." }
            } else {
                problemBanner = nil
                footer = "Checked \(TimeText.time(now, calendar: calendar))"
            }
        } catch {
            problemBanner = ErrorMessage(error)
            footer = nil
        }
    }

    /// After the Plan Editor saves: refreshes Today, and confirms a plan saved
    /// for another day, since it doesn't appear under "Your plans".
    func planWasSaved(_ plan: PlannedActivity?, now: Date = Date()) async {
        await refresh(now: now)
        guard let plan, !calendar.isDate(plan.start, inSameDayAs: now) else {
            toast = nil
            return
        }
        toast = "Saved for \(TimeText.day(plan.start, calendar: calendar))."
    }

    /// After an option is used: refreshes Today and confirms the change.
    func optionWasUsed(toast: String, now: Date = Date()) async {
        await refresh(now: now)
        self.toast = toast
    }

    func dismissToast() {
        toast = nil
    }

    /// The plan behind a row, to open Plan Detail.
    func plan(withID id: UUID) -> PlannedActivity? {
        plansByID[id]
    }

    private func row(for plan: PlannedActivity, check: PlanCheck?, now: Date) -> PlanRow {
        let activityType = ActivityCatalogue.type(withID: plan.typeID)
        let upcomingCheck = PlanDisplayStatus.shownCheck(of: plan, check: check, now: now, calendar: calendar)
        let status = PlanDisplayStatus(plan: plan, check: check, now: now, calendar: calendar)

        var detail = plan.place?.name ?? "Online"
        if let leaveBy = upcomingCheck?.leaveBy, let travel = upcomingCheck?.travel, travel.minutes > 0 {
            detail += " · Leave by \(TimeText.time(leaveBy, calendar: calendar))"
        }

        return PlanRow(
            id: plan.id,
            symbolName: activityType?.symbolName ?? "calendar",
            activityName: activityType?.name ?? plan.title,
            timeText: TimeText.range(plan.start, plan.end, calendar: calendar),
            title: plan.title,
            detail: detail,
            status: status,
            reason: status == .needsAttention
                ? upcomingCheck?.findings.first { $0.severity == .problem }?.message
                : nil,
            isMoved: plan.status == .adjusted
        )
    }

    private func hasMissingSamplePlaces() async -> Bool {
        guard let samplePlaces = try? SamplePlaces.all() else { return false }
        for place in samplePlaces where (try? await places.place(named: place.name)) == nil {
            return true
        }
        return false
    }
}
