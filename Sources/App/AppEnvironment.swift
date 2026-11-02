import Foundation
import Observation

/// Dependency container passed down the view tree.
@MainActor
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let healthKit: any HealthDataProviding
    let mock: any HealthDataProviding
    let calendar: Calendar
    var now: @Sendable () -> Date

    init(
        settings: AppSettings,
        healthKit: any HealthDataProviding,
        mock: any HealthDataProviding,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.healthKit = healthKit
        self.mock = mock
        self.calendar = calendar
        self.now = now
    }

    static func live() -> AppEnvironment {
        AppEnvironment(
            settings: AppSettings(),
            healthKit: HealthKitDataSource(),
            mock: MockHealthDataSource()
        )
    }

#if DEBUG
    static func preview() -> AppEnvironment {
        AppEnvironment(
            settings: AppSettings(persists: false),
            healthKit: MockHealthDataSource(),
            mock: MockHealthDataSource()
        )
    }
#endif

    var dataSource: any HealthDataProviding {
        settings.useMockData ? mock : healthKit
    }

    var periodCalendar: PeriodCalendar {
        PeriodCalendar(calendar: calendar)
    }

    var formatter: MetricFormatter {
        MetricFormatter(units: settings.unitPreferences)
    }

    var periodFormatter: PeriodFormatter {
        PeriodFormatter(calendar: calendar)
    }
}
