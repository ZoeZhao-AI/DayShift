import Foundation
import Testing
@testable import DayShiftKit

struct CheckUpcomingPlansUseCaseTests {
    /// Lin's Thursday with mocks, and the use case under test.
    private struct Setup {
        let day: LinsThursday
        let activities: MockActivityRepository
        let conditions: MockConditionsService
        let travel = MockTravelTimeService()
        let widget = MockWidgetRefresher()
        let notifications = MockNotificationScheduler()
        let useCase: CheckUpcomingPlansUseCase

        init(
            preferences: ComfortPreferences? = nil,
            plans: (LinsThursday) throws -> [PlannedActivity] = { $0.plans }
        ) throws {
            day = try LinsThursday()
            activities = MockActivityRepository(plans: try plans(day), calendar: day.calendar)
            conditions = try MockConditionsService(day)
            travel.setMinutes(5, between: day.home.coordinate, and: day.enmorePark.coordinate)
            useCase = CheckUpcomingPlansUseCase(
                activities: activities,
                places: MockPlaceRepository(places: day.places),
                preferences: MockPreferencesRepository(preferences: preferences),
                conditions: conditions,
                travelTimes: travel,
                widget: widget,
                notifications: notifications,
                calendar: day.calendar
            )
        }
    }

    private func check(for plan: PlannedActivity, in checks: [PlanCheck]) throws -> PlanCheck {
        try #require(checks.first { $0.planID == plan.id })
    }

    @Test("A run during smoke above Lin's limit needs attention")
    func smokyRunNeedsAttention() async throws {
        let setup = try Setup()

        let checks = try await setup.useCase.execute(now: setup.day.now)

        let run = try check(for: setup.day.run, in: checks)
        #expect(run.overallStatus == .needsAttention)
        #expect(run.findings.contains(try PlanFinding(
            factor: .conditions,
            severity: .problem,
            message: "Smoke until 10 am. Air quality Poor, above your limit (Fair)."
        )))
        #expect(run.leaveBy == setup.day.time(6, 55))
    }

    @Test("Focus work at home needs attention when it reaches 33°C outside")
    func focusWorkAtHomeNeedsAttentionInHeat() async throws {
        let setup = try Setup()

        let checks = try await setup.useCase.execute(now: setup.day.now)

        let focusWork = try check(for: setup.day.focusWork, in: checks)
        #expect(focusWork.overallStatus == .needsAttention)
        #expect(focusWork.findings.contains(try PlanFinding(
            factor: .conditions,
            severity: .problem,
            message: "It reaches 33°C outside this afternoon. You've said your room gets too hot above 30°C."
        )))
    }

    @Test("UV 9 on a 4-minute walk is a tip")
    func shortWalkInHighUVIsTip() async throws {
        // Lin walks today; Home to Newtown Library is a 4-minute walk.
        let walking = try ComfortPreferences(
            maxApparentTemperatureC: 32, worstAcceptableAirQuality: .fair, maxUVIndex: 8,
            maxWindGustsKmh: 40, maxRainProbability: 40,
            earliestPlanTime: 6 * 60, latestPlanTime: 21 * 60,
            minimumBufferMinutes: 15, leaveReminderMinutes: 10, travelMode: .walking
        )
        let setup = try Setup(preferences: walking) { day in
            [try PlannedActivity(
                typeID: ActivityCatalogue.focusWork.id, title: "Focus work",
                start: day.time(13), durationMinutes: 240,
                place: day.newtownLibrary, mode: .inPerson,
                flexibility: .fixed
            )]
        }
        setup.travel.setMinutes(4, between: setup.day.home.coordinate, and: setup.day.newtownLibrary.coordinate)

        let checks = try await setup.useCase.execute(now: setup.day.now)

        let focusWork = try #require(checks.first)
        #expect(focusWork.overallStatus == .looksGood)
        #expect(focusWork.findings.contains(try PlanFinding(
            factor: .conditions,
            severity: .tip,
            message: "UV 9 · 4 min outside, wear sunscreen"
        )))
    }

    @Test("A plan with no conditions for its time gets a tip instead of fine conditions")
    func missingConditionsGetTip() async throws {
        let setup = try Setup { [$0.run] }
        setup.conditions.setHours([], at: setup.day.enmorePark.coordinate)

        let checks = try await setup.useCase.execute(now: setup.day.now)

        let run = try check(for: setup.day.run, in: checks)
        let conditionFindings = run.findings.filter { $0.factor == .conditions }
        #expect(conditionFindings == [try PlanFinding(
            factor: .conditions,
            severity: .tip,
            message: "Weather and air quality for this time aren't available."
        )])
    }

    @Test("An online plan skips conditions, travel and crowds")
    func onlinePlanSkipsConditionsTravelAndCrowds() async throws {
        let setup = try Setup { [$0.clientCall] }

        let checks = try await setup.useCase.execute(now: setup.day.now)

        let call = try check(for: setup.day.clientCall, in: checks)
        #expect(call.overallStatus == .looksGood)
        #expect(call.travel == nil && call.leaveBy == nil)
        #expect(call.findings == [
            try PlanFinding(factor: .conditions, severity: .fine, message: "Online, so the weather doesn't affect this plan."),
            try PlanFinding(factor: .travel, severity: .fine, message: "No travel needed."),
            try PlanFinding(factor: .openingHours, severity: .fine, message: "Always available."),
            try PlanFinding(factor: .crowds, severity: .fine, message: "Online, so crowds don't apply.")
        ])
    }

    @Test("The same smoke problem is alerted only once")
    func smokeProblemAlertedOnce() async throws {
        let setup = try Setup { [$0.run] }

        _ = try await setup.useCase.execute(now: setup.day.now)
        _ = try await setup.useCase.execute(now: setup.day.time(6, 42))

        #expect(setup.notifications.planAffectedAlerts.count == 1)
        let alert = try #require(setup.notifications.planAffectedAlerts.first)
        #expect(alert.planID == setup.day.run.id)
        #expect(alert.reasonKeys == ["poorAirQuality"])
        #expect(setup.activities.storedNotifiedReasons[setup.day.run.id] == ["poorAirQuality"])
    }
}
