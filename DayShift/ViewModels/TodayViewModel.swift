import DayShiftKit
import Foundation
import Observation

/// Today's plans with their latest check (Section 7.3). Runs the check when
/// the app becomes active; if conditions are unavailable, shows the last
/// saved checks with when they were made.
@MainActor
@Observable
final class TodayViewModel {
    enum Status: Equatable {
        case looksGood
        case needsAttention
        case notCheckedYet
    }

    struct PlanRow: Identifiable, Equatable {
        let id: UUID
        let symbolName: String
        let activityName: String
        /// e.g. "7:00–7:45 am".
        let timeText: String
        let title: String
        /// e.g. "Enmore Park · Leave by 6:55 am", or "Online".
        let detail: String
        let status: Status
        /// The first problem, shown when the plan needs attention.
        let reason: String?
        let isMoved: Bool
    }

    /// An error in Lin's words: `title` in bold, `detail` below (7.4).
    struct Banner: Equatable {
        let title: String
        let detail: String
    }

    private(set) var weekday = ""
    private(set) var rows: [PlanRow] = []
    private(set) var footer: String?
    private(set) var problemBanner: Banner?
    private(set) var alertsAreOff = false
    private(set) var showsAddSamplePlaces = false
    private(set) var hasLoaded = false

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
    /// aren't saved yet, then refreshes.
    func addSamplePlaces() async {
        do {
            for place in try SamplePlaces.all() where try await places.place(named: place.name) == nil {
                try await places.save(place)
            }
        } catch {
            problemBanner = Self.banner(for: error)
        }
        await refresh()
    }

    private func showPlans(now: Date, checkError: Error?) async {
        do {
            var rows: [PlanRow] = []
            var lastCheckedAt: Date?
            for plan in try await activities.plans(on: now) {
                let check = try await activities.check(for: plan.id)
                if let checkedAt = check?.checkedAt, checkedAt > (lastCheckedAt ?? .distantPast) {
                    lastCheckedAt = checkedAt
                }
                rows.append(row(for: plan, check: check))
            }
            self.rows = rows

            if let checkError {
                problemBanner = Self.banner(for: checkError)
                footer = lastCheckedAt.map { "Statuses from the last check at \(TimeText.time($0, calendar: calendar))." }
            } else {
                problemBanner = nil
                footer = "Checked \(TimeText.time(now, calendar: calendar))"
            }
        } catch {
            problemBanner = Self.banner(for: error)
            footer = nil
        }
    }

    private func row(for plan: PlannedActivity, check: PlanCheck?) -> PlanRow {
        let activityType = ActivityCatalogue.type(withID: plan.typeID)
        let status: Status
        switch check?.overallStatus {
        case .needsAttention: status = .needsAttention
        case .looksGood: status = .looksGood
        case nil: status = .notCheckedYet
        }

        var detail = plan.place?.name ?? "Online"
        if let leaveBy = check?.leaveBy, let travel = check?.travel, travel.minutes > 0 {
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
                ? check?.findings.first { $0.severity == .problem }?.message
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

    static func banner(for error: Error) -> Banner {
        let localized = error as? LocalizedError
        return Banner(
            title: localized?.errorDescription ?? "Something went wrong.",
            detail: localized?.recoverySuggestion ?? "Please try again."
        )
    }
}
