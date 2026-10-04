import CoreLocation
import DayShiftKit

/// Looks up addresses with CLGeocoder, preferring matches around Sydney.
struct CLGeocoderPlaceGeocoder: PlaceGeocoding {
    /// A hint, not a limit: "Newtown" should find Newtown NSW first.
    private static let sydneyRegion = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),
        radius: 100_000,
        identifier: "Sydney"
    )

    func coordinates(for address: String) async throws -> (latitude: Double, longitude: Double, suburb: String?) {
        let placemarks: [CLPlacemark]
        do {
            placemarks = try await CLGeocoder().geocodeAddressString(
                address,
                in: Self.sydneyRegion,
                preferredLocale: Locale(identifier: "en_AU")
            )
        } catch let error as CLError where error.code == .geocodeFoundNoResult {
            throw PlaceGeocodingError.addressNotFound
        } catch {
            throw PlaceGeocodingError.unavailable(underlying: error)
        }

        guard let placemark = placemarks.first, let location = placemark.location else {
            throw PlaceGeocodingError.addressNotFound
        }
        // In Australian addresses the suburb is the placemark's locality.
        return (location.coordinate.latitude, location.coordinate.longitude, placemark.locality)
    }
}
