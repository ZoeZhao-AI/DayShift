import Foundation
import Testing
@testable import DayShiftKit

struct PlaceTests {
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
        let plan = DateInterval(start: LinsThursday.time(16), end: LinsThursday.time(18))

        #expect(hours.isOpen(throughout: plan, calendar: LinsThursday.sydney) == false)
    }
}
