import Foundation

/// A tracked location, kept free of MapKit and CoreLocation so the domain layer
/// stays testable and platform-free.
struct RoutePoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var time: Date?

    init(latitude: Double, longitude: Double, altitude: Double? = nil, time: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.time = time
    }
}

/// Everything the workout detail screen shows beyond the summary.
struct WorkoutDetail: Sendable, Equatable {
    var route: [RoutePoint] = []
    var averageHeartRate: Double?
    var maximumHeartRate: Double?
    var energyKilocalories: Double?

    var hasRoute: Bool { route.count >= 2 }
}

/// One kilometre (or mile) of a workout.
struct WorkoutSplit: Identifiable, Hashable, Sendable {
    let index: Int
    /// Distance of the split in user-facing units (1 for a full split, less for the last one).
    let distance: Double
    let duration: TimeInterval

    var id: Int { index }
    /// Seconds per unit, e.g. 342 for 5:42/km.
    var pace: TimeInterval { distance > 0 ? duration / distance : 0 }
}
