import Foundation
import os

/// The App Group the app and its widget share.
///
/// The widget cannot read HealthKit on its own behalf — asking again there would
/// mean a second permission sheet and a slow query in a snapshot — so the app
/// keeps its daily cache in this shared container and the widget aggregates it
/// with the same domain code the app uses.
enum AppGroup {
    static let identifier = "group.com.defik74.statsWorkout"

    private static let logger = Logger(subsystem: "com.defik74.statsWorkout", category: "AppGroup")

    /// Shared container, or `nil` when the entitlement is missing (unit tests
    /// run outside the group, and an unsigned build has no container).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Where the app's shared files live, falling back to Application Support so
    /// tests and previews still work without the entitlement.
    static func directory(_ name: String) -> URL {
        if let containerURL {
            return containerURL.appending(path: name, directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory.appending(path: name, directoryHint: .isDirectory)
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// The handful of preferences the widget needs, mirrored into the shared
/// defaults whenever they change.
///
/// A widget renders in its own process and cannot read the app's standard
/// defaults, so language and units would otherwise fall back to the device's.
struct SharedPreferences: Codable, Equatable, Sendable {
    var languageCode: String = "en"
    /// Raw values, so the widget can decode them without the app's types.
    var distanceUnit: String = DistanceUnit.kilometers.rawValue
    var elevationUnit: String = ElevationUnit.meters.rawValue
    /// Mirrored so the widget shows demo numbers while the app is in demo mode,
    /// and real ones as soon as that is switched off.
    var useMockData: Bool = false

    static let defaultsKey = "shared.preferences"

    var unitPreferences: UnitPreferences {
        UnitPreferences(
            distanceUnit: DistanceUnit(rawValue: distanceUnit) ?? .kilometers,
            elevationUnit: ElevationUnit(rawValue: elevationUnit) ?? .meters
        )
    }

    var locale: Locale {
        Locale(identifier: languageCode)
    }

    var language: AppLanguage {
        AppLanguage.allCases.first { $0.code == languageCode } ?? .english
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> SharedPreferences {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(SharedPreferences.self, from: data) else {
            return SharedPreferences()
        }
        return value
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
