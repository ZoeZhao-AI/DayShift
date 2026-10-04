import Foundation
import Testing
@testable import DayShiftKit

struct PlannedActivityTests {
    @Test("An online plan cannot have a place")
    func onlinePlanCannotHavePlace() throws {
        let day = try LinsThursday()

        #expect(throws: PlannedActivityError.onlinePlanHasPlace) {
            try PlannedActivity(
                typeID: ActivityCatalogue.clientMeeting.id,
                title: "Client call",
                start: day.time(11),
                durationMinutes: 30,
                place: day.enmorePark,
                mode: .online,
                flexibility: .fixed
            )
        }
    }

    @Test("A movable window shorter than the plan is rejected")
    func movableWindowShorterThanPlanIsRejected() throws {
        let day = try LinsThursday()
        let thirtyMinuteWindow = DateInterval(start: day.time(7), end: day.time(7, 30))

        #expect(throws: PlannedActivityError.movableWindowShorterThanPlan) {
            try PlannedActivity(
                typeID: ActivityCatalogue.run.id,
                title: "Run",
                start: day.time(7),
                durationMinutes: 45,
                place: day.enmorePark,
                mode: .inPerson,
                flexibility: ActivityFlexibility(
                    movableWindow: thirtyMinuteWindow,
                    allowsPlaceChange: false
                )
            )
        }
    }

    @Test("A plan outside its own movable window is rejected")
    func planOutsideMovableWindowIsRejected() throws {
        let day = try LinsThursday()
        let eveningWindow = DateInterval(start: day.time(17), end: day.time(20))

        #expect(throws: PlannedActivityError.planOutsideMovableWindow) {
            try PlannedActivity(
                typeID: ActivityCatalogue.run.id,
                title: "Run",
                start: day.time(7),
                durationMinutes: 45,
                place: day.enmorePark,
                mode: .inPerson,
                flexibility: ActivityFlexibility(
                    movableWindow: eveningWindow,
                    allowsPlaceChange: false
                )
            )
        }
    }
}
