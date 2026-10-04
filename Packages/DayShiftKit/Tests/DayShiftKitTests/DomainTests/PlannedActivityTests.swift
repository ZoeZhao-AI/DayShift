import Foundation
import Testing
@testable import DayShiftKit

struct PlannedActivityTests {
    private let sydney: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }()

    /// Thursday 8 October 2026 at the given time, Sydney time.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        sydney.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    private func enmorePark() throws -> Place {
        try Place(
            name: "Enmore Park",
            kind: .park,
            address: "Enmore Rd, Marrickville NSW 2204",
            latitude: -33.8990,
            longitude: 151.1720,
            isIndoor: false,
            isCooled: false,
            isAlwaysOpen: true
        )
    }

    @Test("An online plan cannot have a place")
    func onlinePlanCannotHavePlace() throws {
        let park = try enmorePark()

        #expect(throws: PlannedActivityError.onlinePlanHasPlace) {
            try PlannedActivity(
                typeID: ActivityCatalogue.clientMeeting.id,
                title: "Client call",
                start: thursday(11),
                durationMinutes: 30,
                place: park,
                mode: .online,
                flexibility: .fixed
            )
        }
    }

    @Test("A movable window shorter than the plan is rejected")
    func movableWindowShorterThanPlanIsRejected() throws {
        let park = try enmorePark()
        let thirtyMinuteWindow = DateInterval(start: thursday(7), end: thursday(7, 30))

        #expect(throws: PlannedActivityError.movableWindowShorterThanPlan) {
            try PlannedActivity(
                typeID: ActivityCatalogue.run.id,
                title: "Run",
                start: thursday(7),
                durationMinutes: 45,
                place: park,
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
        let park = try enmorePark()
        let eveningWindow = DateInterval(start: thursday(17), end: thursday(20))

        #expect(throws: PlannedActivityError.planOutsideMovableWindow) {
            try PlannedActivity(
                typeID: ActivityCatalogue.run.id,
                title: "Run",
                start: thursday(7),
                durationMinutes: 45,
                place: park,
                mode: .inPerson,
                flexibility: ActivityFlexibility(
                    movableWindow: eveningWindow,
                    allowsPlaceChange: false
                )
            )
        }
    }
}
