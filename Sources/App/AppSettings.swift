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
    var dataScope: DataScope { didSet { store(dataScope.rawValue, forKey: Key.dataScope) } }
    var language: AppLanguage { didSet { store(language.rawValue, forKey: Key.language) } }

    private let defaults: UserDefaults
    private let persists: Bool

    init(defaults: UserDefaults = .standard, persists: Bool = true) {
        self.defaults = defaults
        self.persists = persists

        let storedDistance = defaults.string(forKey: Key.distanceUnit).flatMap(DistanceUnit.init(rawValue:))
        let storedElevation = defaults.string(forKey: Key.elevationUnit).flatMap(ElevationUnit.init(rawValue:))
        let storedComparison = defaults.string(forKey: Key.comparisonMode).flatMap(ComparisonMode.init(rawValue:))
        let storedPeriod = defaults.string(forKey: Key.preferredPeriod).flatMap(PeriodKind.init(rawValue:))
        let storedScope = defaults.string(forKey: Key.dataScope).flatMap(DataScope.init(rawValue:))
        let storedLanguage = defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:))

        distanceUnit = storedDistance ?? .kilometers
        elevationUnit = storedElevation ?? .meters
        comparisonMode = storedComparison ?? .previousPeriod
        preferredPeriod = storedPeriod ?? .month
        dataScope = ScreenshotRoute.scope ?? storedScope ?? .all
        language = storedLanguage ?? .system

        if defaults.object(forKey: Key.useMockData) == nil {
            useMockData = Self.defaultsToMockData
        } else {
            useMockData = defaults.bool(forKey: Key.useMockData)
        }
    }

    /// The saved language choice, read before the app builds its view tree so
    /// the catalogs are loaded by the time the first string renders.
    nonisolated static func storedLanguage(in defaults: UserDefaults = .standard) -> AppLanguage {
        defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:)) ?? .system
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
        static let dataScope = "settings.dataScope"
        static let language = "settings.language"
    }
}
