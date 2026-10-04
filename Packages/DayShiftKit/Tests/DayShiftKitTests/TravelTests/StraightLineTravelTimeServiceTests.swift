import Foundation
import Testing
@testable import DayShiftKit

struct StraightLineTravelTimeServiceTests {
    private let service = StraightLineTravelTimeService()

    @Test("The same place is 0 minutes away")
    func samePlaceIsZeroMinutes() throws {
        let day = try LinsThursday()

        let estimate = service.travelEstimate(
            from: day.enmorePark.coordinate,
            to: day.enmorePark.coordinate,
            mode: .publicTransport
        )

        #expect(estimate == TravelEstimate(minutes: 0, mode: .publicTransport))
    }

    @Test("A trip by public transport includes 10 minutes of waiting")
    func publicTransportIncludesWaiting() {
        // 0.09° of latitude due south is 10.0 km in a straight line
        // (Earth radius 6371 km), so 13.0 km by road (× 1.3).
        let enmore = Coordinate(latitude: -33.90, longitude: 151.17)
        let tenKilometresSouth = Coordinate(latitude: -33.99, longitude: 151.17)

        let estimate = service.travelEstimate(from: enmore, to: tenKilometresSouth, mode: .publicTransport)

        // 13.0 km at 20 km/h is 39.03 min, rounded up to 40, plus 10 min waiting.
        #expect(estimate == TravelEstimate(minutes: 50, mode: .publicTransport))
    }

    @Test("A short trip is walked even when Lin travels by public transport")
    func shortTripIsWalked() {
        // 0.005° of latitude due south is 0.56 km in a straight line, 0.72 km by road:
        // 9.6 min on foot, rounded up to 10, which is within 15 minutes.
        let enmore = Coordinate(latitude: -33.900, longitude: 151.17)
        let fiveHundredMetresSouth = Coordinate(latitude: -33.905, longitude: 151.17)

        let estimate = service.travelEstimate(from: enmore, to: fiveHundredMetresSouth, mode: .publicTransport)

        #expect(estimate == TravelEstimate(minutes: 10, mode: .walking))
    }
}
