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
    let sync: HealthSyncCoordinator
    private(set) var backgroundDelivery: HealthKitBackgroundDelivery?
    /// Bumped whenever HealthKit reports new data in the background, so open
    /// screens know to refresh.
    private(set) var healthUpdates = 0
    var now: @Sendable () -> Date

    init(
        settings: AppSettings,
        healthKit: any HealthDataProviding,
        mock: any HealthDataProviding,
        calendar: Calendar = .autoupdatingCurrent,
        cacheStore: any HealthCacheStoring = FileHealthCacheStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.healthKit = healthKit
        self.mock = mock
        self.calendar = calendar
        self.sync = HealthSyncCoordinator(store: cacheStore, calendar: calendar)
        self.now = now
    }

    static func live() -> AppEnvironment {
        AppEnvironment(
            settings: AppSettings(),
            healthKit: HealthKitDataSource(),
            mock: MockHealthDataSource(),
            now: {
                if let fixed = ScreenshotRoute.now { return fixed }
                return Date()
            }
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

    var dataSourceKey: String {
        settings.useMockData ? "mock" : "healthkit"
    }

    /// Starts HealthKit background updates. Called once access exists; the
    /// observers make iOS wake the app when steps or workouts change.
    func startBackgroundDelivery() {
        guard !settings.useMockData, backgroundDelivery == nil else { return }

        let delivery = HealthKitBackgroundDelivery { [weak self] _ in
            Task { @MainActor in
                self?.healthUpdates += 1
            }
        }
        backgroundDelivery = delivery
        delivery.start()
    }

    /// Drops cached samples, e.g. when switching between demo and real data.
    func invalidateCache() {
        Task { await sync.invalidate() }
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
