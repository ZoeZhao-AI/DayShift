import Foundation
import Testing
@testable import DayShiftKit

struct SuggestAlternativesUseCaseTests {
    /// Lin's Thursday with mocks, and the use case under test.
    private struct Setup {
        let day: LinsThursday
        let activities: MockActivityRepository
        let conditions: MockConditionsService
        let travel = MockTravelTimeService()
        let useCase: SuggestAlternativesUseCase

        init(plans: (LinsThursday) throws -> [PlannedActivity] = { $0.plans }) throws {
            day = try LinsThursday()
            activities = MockActivityRepository(plans: try plans(day), calendar: day.calendar)
            conditions = try MockConditionsService(day)
            travel.setMinutes(5, between: day.home.coordinate, and: day.enmorePark.coordinate)
            useCase = SuggestAlternativesUseCase(
                activities: activities,
                places: MockPlaceRepository(places: day.places),
                preferences: MockPreferencesRepository(),
                conditions: conditions,
                travelTimes: travel,
                calendar: day.calendar
            )
        }

        /// Lin's Thursday hours at a place, with some values changed by hour.
        func setHours(at place: Place, _ change: (_ hour: Int, _ conditions: HourlyConditions) -> HourlyConditions.Changes) throws {
            let hours = try day.hourlyConditions().enumerated().map { hour, conditions in
                let changes = change(hour, conditions)
                return try HourlyConditions(
                    time: conditions.time,
                    temperatureC: conditions.temperatureC,
                    apparentTemperatureC: conditions.apparentTemperatureC,
                    precipitationProbability: changes.precipitationProbability ?? conditions.precipitationProbability,
                    uvIndex: changes.uvIndex ?? conditions.uvIndex,
                    windGustsKmh: changes.windGustsKmh ?? conditions.windGustsKmh,
                    pm25: changes.pm25 ?? conditions.pm25
                )
            }
            conditions.setHours(hours, at: place.coordinate)
        }
    }

    @Test("A smoky morning run moves to 5:30 pm and the grocery run follows")
    func smokyRunMovesToEvening() async throws {
        let setup = try Setup()
        // As in the prototype: smoke lingers until 11 am, UV is low in the
        // evening, and rain is likely from 7 pm, so neither 10:00 am nor
        // 6:30 pm works.
        try setup.setHours(at: setup.day.enmorePark) { hour, _ in
            HourlyConditions.Changes(
                precipitationProbability: hour >= 19 ? 60 : nil,
                uvIndex: hour >= 17 ? 1 : nil,
                pm25: hour < 11 ? 60 : nil
            )
        }

        let suggestions = try await setup.useCase.execute(for: setup.day.run, now: setup.day.now)

        let best = try #require(suggestions.options.first)
        #expect(best.planID == setup.day.run.id)
        #expect(best.adjustment == .shiftTime(newStart: setup.day.time(17, 30)))
        #expect(best.knockOn == KnockOnChange(
            planID: setup.day.groceryRun.id,
            title: "Grocery run",
            newStart: setup.day.time(18, 30)
        ))
        #expect(best.explanation == "Air quality returns to Good and UV is low.")
        #expect(best.scheduleNote == "Grocery run moves from 5:30 to 6:30 pm. Your 11 am client call is not affected.")
    }

    @Test("The fixed client call is never moved and every option keeps its duration")
    func fixedCallNeverMovesAndDurationsAreKept() async throws {
        let setup = try Setup()
        let day = setup.day
        let call = day.clientCall.interval

        let options = try await setup.useCase.execute(for: day.run, now: day.now).options

        #expect(!options.isEmpty)
        for option in options {
            #expect(option.knockOn?.planID != day.clientCall.id)
            if case let .shiftTime(newStart) = option.adjustment {
                // The run keeps its 45 minutes, so it must still fit around the call.
                let run = DateInterval(start: newStart, duration: TimeInterval(day.run.durationMinutes * 60))
                #expect(!run.intersects(call) || run.end == call.start || run.start == call.end)
            }
            if let knockOn = option.knockOn, let window = day.groceryRun.flexibility.movableWindow {
                // The grocery run keeps its 30 minutes inside its own window.
                let grocery = DateInterval(start: knockOn.newStart, duration: TimeInterval(day.groceryRun.durationMinutes * 60))
                #expect(window.start <= grocery.start && grocery.end <= window.end)
            }
        }
    }

    @Test("A fixed plan gives planHasNoFlexibility")
    func fixedPlanHasNoFlexibility() async throws {
        let setup = try Setup()

        await #expect(throws: SuggestAlternativesError.planHasNoFlexibility) {
            try await setup.useCase.execute(for: setup.day.clientCall, now: setup.day.now)
        }
    }

    @Test("Focus work moves to Newtown Library on a hot afternoon")
    func focusWorkMovesToLibrary() async throws {
        let setup = try Setup()

        let suggestions = try await setup.useCase.execute(for: setup.day.focusWork, now: setup.day.now)

        let best = try #require(suggestions.options.first)
        #expect(best.adjustment == .changePlace(setup.day.newtownLibrary))
        #expect(best.knockOn == nil)
    }

    @Test("A plan that looks good gets other good options")
    func planThatLooksGoodGetsOptions() async throws {
        // Focus work at Newtown Library 9–10 am: air-conditioned, usually quiet,
        // nothing moves. It can move until noon, so there are other good times,
        // even though none can beat it.
        var libraryMorning: PlannedActivity?
        let setup = try Setup { day in
            let plan = try PlannedActivity(
                typeID: ActivityCatalogue.focusWork.id, title: "Focus work",
                start: day.time(9), durationMinutes: 60,
                place: day.newtownLibrary, mode: .inPerson,
                flexibility: ActivityFlexibility(
                    movableWindow: DateInterval(start: day.time(9), end: day.time(12)),
                    allowsPlaceChange: false
                )
            )
            libraryMorning = plan
            return [plan, day.clientCall]
        }
        let plan = try #require(libraryMorning)

        let suggestions = try await setup.useCase.execute(for: plan, now: setup.day.now)

        #expect(!suggestions.options.isEmpty)
        #expect(suggestions.options.allSatisfy { $0.score <= suggestions.currentScore })
        #expect(suggestions.options.allSatisfy { !$0.explanation.isEmpty })
    }

    @Test("No time or place within Lin's limits gives noViableAlternative")
    func noViableAlternative() async throws {
        // Outdoor sketching at Enmore Park with gusts of 55 km/h all day
        // (prototype OptionsNone). It may move all day and change place, but
        // Enmore Park is Lin's only place that suits it.
        var sketching: PlannedActivity?
        let setup = try Setup { day in
            let plan = try PlannedActivity(
                typeID: ActivityCatalogue.outdoorSketching.id, title: "Outdoor sketching",
                start: day.time(18, 15), durationMinutes: 60,
                place: day.enmorePark, mode: .inPerson,
                flexibility: ActivityFlexibility(
                    movableWindow: DateInterval(start: day.time(6), end: day.time(21)),
                    allowsPlaceChange: true
                )
            )
            sketching = plan
            return [plan]
        }
        try setup.setHours(at: setup.day.enmorePark) { _, _ in
            HourlyConditions.Changes(windGustsKmh: 55)
        }
        let plan = try #require(sketching)

        await #expect(throws: SuggestAlternativesError.noViableAlternative) {
            try await setup.useCase.execute(for: plan, now: setup.day.now)
        }
    }
}

extension HourlyConditions {
    /// Values to change in a scripted hour; nil keeps the fixture's value.
    struct Changes {
        var precipitationProbability: Int?
        var uvIndex: Double?
        var windGustsKmh: Double?
        var pm25: Double?
    }
}
