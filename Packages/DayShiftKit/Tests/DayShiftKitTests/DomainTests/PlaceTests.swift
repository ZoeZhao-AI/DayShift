import Foundation
import Testing
@testable import DayShiftKit

struct PlaceTests {
    private let sydney: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }()

    /// Thursday 8 October 2026 at the given time, Sydney time.
    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date {
        sydney.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    @Test("An outdoor place cannot be air-conditioned")
    func outdoorPlaceCannotBeCooled() {
        #expect(throws: PlaceError.outdoorPlaceCannotBeCooled) {
            try Place(
                name: "Enmore Park",
                kind: .park,
                address: "Enmore Rd, Marrickville NSW 2204",
                latitude: -33.8990,
                longitude: 151.1720,
                isIndoor: false,
                isCooled: true,
                isAlwaysOpen: true
            )
        }
    }

    @Test("A library closing at 5 pm is not open for a plan ending at 6 pm")
    func libraryClosedBeforePlanEnds() throws {
        let hours = try OpeningHours(opensAt: 9 * 60, closesAt: 17 * 60, closedWeekdays: [])
        let plan = DateInterval(start: thursday(16), end: thursday(18))

        #expect(hours.isOpen(throughout: plan, calendar: sydney) == false)
    }
}
