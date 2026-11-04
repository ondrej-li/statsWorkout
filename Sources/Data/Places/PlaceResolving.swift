import CoreLocation
import Foundation

/// Turns a coordinate into the settlement a person would name.
protocol PlaceResolving: Sendable {
    func placeName(near point: RoutePoint) async -> String?
}

/// Reverse geocoding through CoreLocation, cached per rounded coordinate so a
/// workout list does not hammer the geocoder.
///
/// Main-actor isolated because `CLGeocoder` is not thread-safe; the calls are
/// short and already asynchronous.
@MainActor
final class CoreLocationPlaceResolver: PlaceResolving {
    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]

    func placeName(near point: RoutePoint) async -> String? {
        let key = Self.key(for: point)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else { return nil }

        let name = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
        if let name { cache[key] = name }
        return name
    }

    /// ~1 km of precision is plenty for a town name and keeps the cache small.
    private static func key(for point: RoutePoint) -> String {
        String(format: "%.2f,%.2f", point.latitude, point.longitude)
    }
}

/// Demo equivalent: the nearest of the towns the synthetic routes are drawn around.
struct MockPlaceResolver: PlaceResolving {
    func placeName(near point: RoutePoint) async -> String? {
        MockTown.nearest(to: point)?.name
    }
}
