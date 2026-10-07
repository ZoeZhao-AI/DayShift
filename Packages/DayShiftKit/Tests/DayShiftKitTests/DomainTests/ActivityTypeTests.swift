import Foundation
import Testing
@testable import DayShiftKit

struct ActivityTypeTests {
    @Test("A run can use an outdoor place of kind Other")
    func runCanUseOutdoorOtherPlace() throws {
        let day = try LinsThursday()
        // Lin runs from her door: an outdoor place of kind Other.
        let aroundHome = try Place(
            name: "Around home", kind: .other, address: day.home.address,
            latitude: day.home.latitude, longitude: day.home.longitude, suburb: "Enmore",
            isIndoor: false, isCooled: false, isAlwaysOpen: true
        )
        // An indoor place of kind Other, such as a friend's flat.
        let friendsFlat = try Place(
            name: "Mia's flat", kind: .other, address: "3 King St, Newtown NSW 2042",
            latitude: -33.8960, longitude: 151.1800, suburb: "Newtown",
            isIndoor: true, isCooled: false, isAlwaysOpen: true
        )

        #expect(ActivityCatalogue.run.suits(aroundHome))
        #expect(ActivityCatalogue.walk.suits(aroundHome))
        #expect(ActivityCatalogue.cycling.suits(aroundHome))
        // Indoor Other places stay unsuitable for outdoor exercise.
        #expect(!ActivityCatalogue.run.suits(friendsFlat))
        // Other activities keep their own kinds: Focus work doesn't move outdoors.
        #expect(!ActivityCatalogue.focusWork.suits(aroundHome))
        // Places of a suitable kind still suit, as before.
        #expect(ActivityCatalogue.run.suits(day.enmorePark))
    }
}
