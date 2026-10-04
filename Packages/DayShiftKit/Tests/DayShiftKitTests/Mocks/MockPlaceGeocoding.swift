import Foundation
@testable import DayShiftKit

/// Scripted addresses. An unknown address throws `PlaceGeocodingError.addressNotFound`,
/// like `CLGeocoderPlaceGeocoder`. Records every address looked up.
/// Set `errorToThrow` to make every call fail.
final class MockPlaceGeocoding: PlaceGeocoding {
    typealias Result = (latitude: Double, longitude: Double, suburb: String?)

    var errorToThrow: Error?
    private(set) var requestedAddresses: [String] = []

    private var resultsByAddress: [String: Result]

    init(resultsByAddress: [String: Result] = [:]) {
        self.resultsByAddress = resultsByAddress
    }

    /// Every address of Lin's places resolves to that place's coordinates and suburb.
    convenience init(_ day: LinsThursday) {
        self.init(resultsByAddress: Dictionary(uniqueKeysWithValues: day.places.map {
            ($0.address, ($0.latitude, $0.longitude, $0.suburb))
        }))
    }

    func coordinates(for address: String) async throws -> Result {
        requestedAddresses.append(address)
        if let errorToThrow { throw errorToThrow }
        guard let result = resultsByAddress[address] else {
            throw PlaceGeocodingError.addressNotFound
        }
        return result
    }
}
