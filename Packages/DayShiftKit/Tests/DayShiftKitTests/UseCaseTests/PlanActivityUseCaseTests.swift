import Foundation
import Testing
@testable import DayShiftKit

struct PlanActivityUseCaseTests {
    /// Lin's Thursday with mocks, and the use case under test.
    private struct Setup {
        let day: LinsThursday
        let activities: MockActivityRepository
        let travel = MockTravelTimeService()
        let planChecker = MockPlanChecker()
        let widget = MockWidgetRefresher()
        let notifications = MockNotificationScheduler()
        let useCase: PlanActivityUseCase

        init(plans: (LinsThursday) -> [PlannedActivity]) throws {
            day = try LinsThursday()
            activities = MockActivityRepository(plans: plans(day), calendar: day.calendar)
            // Prototype: "5 min walk · Leave by 6:55 am" from Home to Enmore Park.
            travel.setMinutes(5, between: day.home.coordinate, and: day.enmorePark.coordinate)
            useCase = PlanActivityUseCase(
                activities: activities,
                places: MockPlaceRepository(places: day.places),
                preferences: MockPreferencesRepository(),
                travelTimes: travel,
                planChecker: planChecker,
                widget: widget,
                notifications: notifications,
                calendar: day.calendar
            )
        }
    }

    @Test("A valid run is saved, the widget refreshes and a leave reminder is scheduled")
    func validRunIsSaved() async throws {
        let setup = try Setup { [$0.clientCall, $0.focusWork, $0.groceryRun] }
        let run = setup.day.run

        try await setup.useCase.execute(run, now: setup.day.now)

        #expect(setup.activities.savedPlans == [run])
        #expect(setup.planChecker.checkedPlans == [run])
        #expect(setup.widget.reloadCount == 1)

        let reminder = try #require(setup.notifications.leaveReminders.first)
        #expect(setup.notifications.leaveReminders.count == 1)
        #expect(reminder.planID == run.id)
        #expect(reminder.placeName == "Enmore Park")
        #expect(reminder.travel.minutes == 5)
        #expect(reminder.leaveBy == setup.day.time(6, 55))
        // Lin's leave reminder is 10 minutes before she needs to go.
        #expect(reminder.fireAt == setup.day.time(6, 45))
    }

    @Test("A plan overlapping the 11 am client call is rejected")
    func overlappingPlanIsRejected() async throws {
        let setup = try Setup { $0.plans }
        let meeting = try PlannedActivity(
            typeID: ActivityCatalogue.clientMeeting.id,
            title: "Client meeting",
            start: setup.day.time(10, 45),
            durationMinutes: 45,
            place: nil,
            mode: .online,
            flexibility: .fixed
        )

        await #expect(throws: PlanActivityError.overlaps(title: "Client call", time: setup.day.time(11))) {
            try await setup.useCase.execute(meeting, now: setup.day.now)
        }
        #expect(setup.activities.savedPlans.isEmpty)
        #expect(setup.widget.reloadCount == 0)
        #expect(setup.notifications.leaveReminders.isEmpty)
    }

    @Test("A plan starting in the past is rejected")
    func planInThePastIsRejected() async throws {
        let setup = try Setup { _ in [] }
        let earlyRun = try PlannedActivity(
            typeID: ActivityCatalogue.run.id,
            title: "Run",
            start: setup.day.time(6),
            durationMinutes: 30,
            place: setup.day.enmorePark,
            mode: .inPerson,
            flexibility: .fixed
        )

        await #expect(throws: PlanActivityError.startsInThePast) {
            try await setup.useCase.execute(earlyRun, now: setup.day.now)
        }
        #expect(setup.activities.savedPlans.isEmpty)
    }

    @Test("A plan at a library that closes before the plan ends is rejected")
    func libraryClosedBeforePlanEndsIsRejected() async throws {
        let setup = try Setup { _ in [] }
        // Newtown Library closes at 6 pm; this plan runs until 7 pm.
        let lateFocusWork = try PlannedActivity(
            typeID: ActivityCatalogue.focusWork.id,
            title: "Focus work",
            start: setup.day.time(15),
            durationMinutes: 240,
            place: setup.day.newtownLibrary,
            mode: .inPerson,
            flexibility: .fixed
        )

        await #expect(throws: PlanActivityError.placeClosed(name: "Newtown Library")) {
            try await setup.useCase.execute(lateFocusWork, now: setup.day.now)
        }
        #expect(setup.activities.savedPlans.isEmpty)
    }
}
