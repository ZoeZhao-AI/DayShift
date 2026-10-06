import Foundation
import Testing
@testable import DayShiftKit

struct SavePlaceUseCaseTests {
    /// Lin's four places, the geocoder that knows their addresses, and the use case.
    private struct Setup {
        let day: LinsThursday
        let places: MockPlaceRepository
        let geocoder: MockPlaceGeocoding
        let useCase: SavePlaceUseCase

        init() throws {
            day = try LinsThursday()
            places = MockPlaceRepository(places: day.places)
            geocoder = MockPlaceGeocoding(day)
            useCase = SavePlaceUseCase(places: places, geocoder: geocoder)
        }
    }

    @Test("A second place called Home is rejected")
    func secondHomeIsRejected() async throws {
        let setup = try Setup()
        // A new place, typed as "home " — names are compared ignoring case and spaces.
        let draft = PlaceDraft(
            name: "home ",
            kind: .home,
            address: "12 Station St, Newtown NSW 2042",
            isIndoor: true,
            isCooled: false,
            uncooledHeatLimitC: 30,
            isAlwaysOpen: true,
            openingHours: nil
        )

        await #expect(throws: SavePlaceError.duplicateName(name: "Home")) {
            try await setup.useCase.execute(draft)
        }
        #expect(setup.places.savedPlaces.isEmpty)
        // The name is checked before the address is looked up.
        #expect(setup.geocoder.requestedAddresses.isEmpty)
    }

    @Test("An address that can't be found is rejected")
    func unknownAddressIsRejected() async throws {
        let setup = try Setup()
        let draft = PlaceDraft(
            name: "Marrickville Library",
            kind: .library,
            address: "1 Nowhere Lane, Atlantis",
            isIndoor: true,
            isCooled: true,
            uncooledHeatLimitC: nil,
            isAlwaysOpen: false,
            openingHours: try OpeningHours(opensAt: 10 * 60, closesAt: 20 * 60, closedWeekdays: [])
        )

        await #expect(throws: SavePlaceError.addressNotFound) {
            try await setup.useCase.execute(draft)
        }
        #expect(setup.geocoder.requestedAddresses == ["1 Nowhere Lane, Atlantis"])
        #expect(setup.places.savedPlaces.isEmpty)
    }
}
