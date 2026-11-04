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
    private let realPlaces: any PlaceResolving
    private let mockPlaces: any PlaceResolving
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
        realPlaces: any PlaceResolving = CoreLocationPlaceResolver(),
        mockPlaces: any PlaceResolving = MockPlaceResolver(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settings = settings
        self.healthKit = healthKit
        self.mock = mock
        self.calendar = calendar
        self.sync = HealthSyncCoordinator(store: cacheStore, calendar: calendar)
        self.realPlaces = realPlaces
        self.mockPlaces = mockPlaces
        self.now = now
    }

    /// Placeholder used while a detail view builds its own model; the real
    /// environment is injected by the view hierarchy.
    @MainActor static let placeholder = AppEnvironment(
        settings: AppSettings(persists: false),
        healthKit: MockHealthDataSource(),
        mock: MockHealthDataSource(),
        cacheStore: TransientHealthCacheStore()
    )

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

struct TransientHealthCacheStore: HealthCacheStoring {
    func load() async -> HealthSampleCache? { nil }
    func save(_ cache: HealthSampleCache) async {}
    func clear() async {}
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

    /// Names the place a workout happened in; demo data uses the demo towns.
    var places: any PlaceResolving {
        settings.useMockData ? mockPlaces : realPlaces
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
