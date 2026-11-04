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
    /// Settlement per workout (`ActivitySample.stableID`), resolved once and cached.
    private(set) var workoutPlaces: [String: String] = [:]
    private var resolvingPlaces: Set<String> = []
    private var didLoadPlaces = false
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

    /// Names the place a workout happened in; demo data uses the demo towns.
    var places: any PlaceResolving {
        settings.useMockData ? mockPlaces : realPlaces
    }

    var dataSourceKey: String {
        settings.useMockData ? "mock" : "healthkit"
    }

    /// The source a workout came from. A workout recorded by Apple Health always
    /// carries its HealthKit identity, so it is always resolved against
    /// HealthKit - flipping the demo switch must never dress a real workout in a
    /// generated route.
    func dataSource(for activity: ActivitySample) -> any HealthDataProviding {
        activity.healthKitUUID == nil ? mock : healthKit
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

    // MARK: - Workout naming

    /// "Your morning walk around Brtnice"; falls back to "Your morning walk"
    /// until the place has been resolved.
    func workoutTitle(for activity: ActivitySample) -> String {
        naming.title(for: activity, place: workoutPlaces[activity.stableID])
    }

    var naming: WorkoutNaming {
        WorkoutNaming(calendar: calendar)
    }

    /// Resolves place names for the workouts that do not have one yet. Runs in
    /// the background as the list appears, so rows rename themselves from
    /// "Morning walk" to "Morning walk around Brtnice".
    func resolveWorkoutPlaces(for activities: [ActivitySample], limit: Int = 8) async {
        if !didLoadPlaces {
            didLoadPlaces = true
            let cached = await sync.placeNames(sourceKey: dataSourceKey)
            if !cached.isEmpty {
                workoutPlaces.merge(cached) { _, new in new }
            }
        }

        let pending = activities
            .filter { $0.kind.isDistanceBased && workoutPlaces[$0.stableID] == nil && !resolvingPlaces.contains($0.stableID) }
            .prefix(limit)
        guard !pending.isEmpty else { return }

        for activity in pending {
            resolvingPlaces.insert(activity.stableID)
            defer { resolvingPlaces.remove(activity.stableID) }

            guard let detail = try? await dataSource(for: activity).workoutDetail(for: activity),
                  let centre = RouteGeometry.centroid(of: detail.route),
                  let place = await places.placeName(near: centre) else { continue }

            workoutPlaces[activity.stableID] = place
            await sync.setPlaceName(place, for: activity.stableID, sourceKey: dataSourceKey)
        }
    }

    /// Records a place found by another screen (the detail view) so the list
    /// picks it up without geocoding twice.
    func rememberPlace(_ place: String, for activity: ActivitySample) async {
        guard workoutPlaces[activity.stableID] != place else { return }
        workoutPlaces[activity.stableID] = place
        await sync.setPlaceName(place, for: activity.stableID, sourceKey: dataSourceKey)
    }

    /// Drops cached samples, e.g. when switching between demo and real data.
    func invalidateCache() {
        workoutPlaces = [:]
        didLoadPlaces = false
        Task { await sync.invalidate() }
    }

    var periodCalendar: PeriodCalendar {
        PeriodCalendar(calendar: calendar)
    }

    /// Locale of the language the app was started in, so dates and numbers match
    /// the chosen language rather than the device.
    var locale: Locale { L10n.shared.locale }

    var formatter: MetricFormatter {
        MetricFormatter(units: settings.unitPreferences, locale: locale)
    }

    var periodFormatter: PeriodFormatter {
        PeriodFormatter(calendar: calendar, locale: locale)
    }
}
