import Foundation
import Testing
@testable import DayShiftKit

struct AcceptAlternativeUseCaseTests {
    /// Lin's Thursday with mocks, and the use case under test.
    private struct Setup {
        let day: LinsThursday
        let activities: MockActivityRepository
        let conditions: MockConditionsService
        let travel = MockTravelTimeService()
        let planChecker = MockPlanChecker()
        let widget = MockWidgetRefresher()
        let notifications = MockNotificationScheduler()
        let useCase: AcceptAlternativeUseCase

        init(places: (LinsThursday) throws -> [Place] = { $0.places }) throws {
            day = try LinsThursday()
            activities = MockActivityRepository(plans: day.plans, calendar: day.calendar)
            conditions = try MockConditionsService(day)
            travel.setMinutes(5, between: day.home.coordinate, and: day.enmorePark.coordinate)
            useCase = AcceptAlternativeUseCase(
                activities: activities,
                places: MockPlaceRepository(places: try places(day)),
                preferences: MockPreferencesRepository(),
                conditions: conditions,
                travelTimes: travel,
                planChecker: planChecker,
                widget: widget,
                notifications: notifications,
                calendar: day.calendar
            )
        }

        /// The prototype's evening at Enmore Park: smoke until 11 am, low UV
        /// from 5 pm, rain likely from 7 pm (as in the 5:30 pm option test).
        func useEveningRunConditions() throws {
            let hours = try day.hourlyConditions().enumerated().map { hour, conditions in
                try HourlyConditions(
                    time: conditions.time,
                    temperatureC: conditions.temperatureC,
                    apparentTemperatureC: conditions.apparentTemperatureC,
                    precipitationProbability: hour >= 19 ? 60 : conditions.precipitationProbability,
                    uvIndex: hour >= 17 ? 1 : conditions.uvIndex,
                    windGustsKmh: conditions.windGustsKmh,
                    pm25: hour < 11 ? 60 : conditions.pm25
                )
            }
            conditions.setHours(hours, at: day.enmorePark.coordinate)
        }

        /// "Move to 5:30 pm · Enmore Park", with the grocery run moving to 6:30 pm.
        func eveningRunOption() throws -> AlternativePlan {
            try AlternativePlan(
                planID: day.run.id,
                adjustment: .shiftTime(newStart: day.time(17, 30)),
                knockOn: KnockOnChange(planID: day.groceryRun.id, title: "Grocery run", newStart: day.time(18, 30)),
                score: 24,
                explanation: "Air quality returns to Good and UV is low.",
                scheduleNote: "Grocery run moves from 5:30 to 6:30 pm. Your 11 am client call is not affected."
            )
        }
    }

    @Test("Accepting the run option saves both plans together with two records and refreshes the widget")
    func acceptingRunOptionSavesBothPlans() async throws {
        let setup = try Setup()
        try setup.useEveningRunConditions()
        let day = setup.day

        try await setup.useCase.execute(try setup.eveningRunOption(), now: day.now)

        #expect(setup.activities.appliedAdjustmentCount == 1)
        let run = try #require(setup.activities.storedPlans[day.run.id])
        let grocery = try #require(setup.activities.storedPlans[day.groceryRun.id])
        #expect(run.start == day.time(17, 30) && run.status == .adjusted)
        #expect(grocery.start == day.time(18, 30) && grocery.status == .adjusted)
        #expect(run.durationMinutes == 45 && grocery.durationMinutes == 30)

        let records = setup.activities.storedRecords
        #expect(records.count == 2)
        let runRecord = try #require(records.first { $0.planID == day.run.id })
        #expect(runRecord.kind == .shiftTime)
        #expect(runRecord.previousStart == day.time(7) && runRecord.newStart == day.time(17, 30))
        #expect(runRecord.reason == "Smoke")
        let groceryRecord = try #require(records.first { $0.planID == day.groceryRun.id })
        #expect(groceryRecord.previousStart == day.time(17, 30) && groceryRecord.newStart == day.time(18, 30))
        #expect(groceryRecord.reason == "Made room for Run")

        #expect(setup.widget.reloadCount == 1)
        #expect(Set(setup.notifications.removedPlanIDs) == [day.run.id, day.groceryRun.id])
        // The rest of the day is checked again with the new times.
        #expect(Set(setup.planChecker.checkedPlans.map(\.id)) == Set(day.plans.map(\.id)))
    }

    @Test("Accepting after the plan has started gives planAlreadyStarted")
    func acceptingAfterStartIsRejected() async throws {
        let setup = try Setup()
        try setup.useEveningRunConditions()

        await #expect(throws: AcceptAlternativeError.planAlreadyStarted) {
            try await setup.useCase.execute(try setup.eveningRunOption(), now: setup.day.time(7, 5))
        }
        #expect(setup.activities.appliedAdjustmentCount == 0)
        #expect(setup.widget.reloadCount == 0)
    }

    @Test("An option whose library now closes too early gives noLongerAvailable")
    func libraryClosingEarlyIsNoLongerAvailable() async throws {
        // Since the option was suggested, Lin changed Newtown Library to close at 4 pm.
        let setup = try Setup { day in
            let library = day.newtownLibrary
            let closesEarly = try Place(
                id: library.id, name: library.name, kind: library.kind, address: library.address,
                latitude: library.latitude, longitude: library.longitude, suburb: library.suburb,
                isIndoor: true, isCooled: true, isAlwaysOpen: false,
                openingHours: OpeningHours(opensAt: 9 * 60, closesAt: 16 * 60, closedWeekdays: [])
            )
            return [day.home, closesEarly, day.enmorePark, day.marrickvilleMetro]
        }
        let day = setup.day
        let option = try AlternativePlan(
            planID: day.focusWork.id,
            adjustment: .changePlace(day.newtownLibrary),
            knockOn: nil,
            score: 80,
            explanation: "Air-conditioned, so the heat doesn't matter. Open until 6 pm, 10 min by public transport.",
            scheduleNote: "Nothing else moves. Your 11 am client call is not affected."
        )

        await #expect(throws: AcceptAlternativeError.noLongerAvailable(reason: "Newtown Library closes at 4 pm")) {
            try await setup.useCase.execute(option, now: day.now)
        }
        #expect(setup.activities.appliedAdjustmentCount == 0)
        #expect(setup.activities.storedPlans[day.focusWork.id] == day.focusWork)
    }

    @Test("If saving fails, the original plans are unchanged")
    func failedSaveLeavesPlansUnchanged() async throws {
        let setup = try Setup()
        try setup.useEveningRunConditions()
        setup.activities.applyAdjustmentErrorToThrow = PersistenceError.couldNotSave(underlying: CocoaError(.fileWriteUnknown))
        let day = setup.day

        await #expect(throws: AcceptAlternativeError.saveFailed) {
            try await setup.useCase.execute(try setup.eveningRunOption(), now: day.now)
        }
        #expect(setup.activities.storedPlans[day.run.id] == day.run)
        #expect(setup.activities.storedPlans[day.groceryRun.id] == day.groceryRun)
        #expect(setup.activities.storedRecords.isEmpty)
        #expect(setup.widget.reloadCount == 0)
        #expect(setup.notifications.removedPlanIDs.isEmpty)
    }
}
