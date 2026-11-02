import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case kilometers
    case miles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    func value(fromMeters meters: Double) -> Double {
        switch self {
        case .kilometers: return meters / 1_000
        case .miles: return meters / 1_609.344
        }
    }
}

enum ElevationUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case meters
    case feet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meters: return "Meters"
        case .feet: return "Feet"
        }
    }

    var symbol: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        }
    }

    func value(fromMeters meters: Double) -> Double {
        switch self {
        case .meters: return meters
        case .feet: return meters / 0.3048
        }
    }
}

/// User-visible measurement preferences.
struct UnitPreferences: Equatable, Sendable {
    var distanceUnit: DistanceUnit
    var elevationUnit: ElevationUnit

    static let metric = UnitPreferences(distanceUnit: .kilometers, elevationUnit: .meters)
    static let imperial = UnitPreferences(distanceUnit: .miles, elevationUnit: .feet)
}
