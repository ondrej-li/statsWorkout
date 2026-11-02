import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    var distanceUnit: DistanceUnit { didSet { store(distanceUnit.rawValue, forKey: Key.distanceUnit) } }
    var elevationUnit: ElevationUnit { didSet { store(elevationUnit.rawValue, forKey: Key.elevationUnit) } }
    var comparisonMode: ComparisonMode { didSet { store(comparisonMode.rawValue, forKey: Key.comparisonMode) } }
    var preferredPeriod: PeriodKind { didSet { store(preferredPeriod.rawValue, forKey: Key.preferredPeriod) } }
    var useMockData: Bool { didSet { store(useMockData, forKey: Key.useMockData) } }

    private let defaults: UserDefaults
    private let persists: Bool

    init(defaults: UserDefaults = .standard, persists: Bool = true) {
        self.defaults = defaults
        self.persists = persists

        let storedDistance = defaults.string(forKey: Key.distanceUnit).flatMap(DistanceUnit.init(rawValue:))
        let storedElevation = defaults.string(forKey: Key.elevationUnit).flatMap(ElevationUnit.init(rawValue:))
        let storedComparison = defaults.string(forKey: Key.comparisonMode).flatMap(ComparisonMode.init(rawValue:))
        let storedPeriod = defaults.string(forKey: Key.preferredPeriod).flatMap(PeriodKind.init(rawValue:))

        distanceUnit = storedDistance ?? .kilometers
        elevationUnit = storedElevation ?? .meters
        comparisonMode = storedComparison ?? .previousPeriod
        preferredPeriod = storedPeriod ?? .month

        if defaults.object(forKey: Key.useMockData) == nil {
            useMockData = Self.defaultsToMockData
        } else {
            useMockData = defaults.bool(forKey: Key.useMockData)
        }
    }

    nonisolated static var defaultsToMockData: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var unitPreferences: UnitPreferences {
        UnitPreferences(distanceUnit: distanceUnit, elevationUnit: elevationUnit)
    }

    private func store(_ value: Any, forKey key: String) {
        guard persists else { return }
        defaults.set(value, forKey: key)
    }

    private enum Key {
        static let distanceUnit = "settings.distanceUnit"
        static let elevationUnit = "settings.elevationUnit"
        static let comparisonMode = "settings.comparisonMode"
        static let preferredPeriod = "settings.preferredPeriod"
        static let useMockData = "settings.useMockData"
    }
}
