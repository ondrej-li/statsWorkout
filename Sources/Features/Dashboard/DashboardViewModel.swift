import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case needsAuthorization
        case failed(String)
    }

    struct LoadRequest: Hashable {
        let range: PeriodRange
        let comparison: ComparisonMode
        let useMockData: Bool
    }

    var periodKind: PeriodKind
    var range: PeriodRange
    var metric: Metric = ScreenshotRoute.metric ?? .steps
    var selectedBucketIndex: Int?
    var phase: Phase = .loading
    var aggregated: AggregatedStats?
    var recentActivities: [ActivitySample] = []

    var stats: PeriodStats? { aggregated?.stats(for: dataScope) }

    /// Which samples the dashboard shows. Switching is instant: both scopes are
    /// computed from the samples that were already fetched.
    var dataScope: DataScope {
        get { settings.dataScope }
        set { settings.dataScope = newValue }
    }
    var isRequestingAuthorization = false
    var customStart: Date
    var customEnd: Date

    private let environment: AppEnvironment
    private var loadGeneration = 0

    init(environment: AppEnvironment) {
        self.environment = environment
        let now = environment.now()
        let kind = ScreenshotRoute.period ?? environment.settings.preferredPeriod
        var range = environment.periodCalendar.range(for: kind, containing: now)
        if ScreenshotRoute.periodOffset != 0 {
            range = environment.periodCalendar.offset(range, by: ScreenshotRoute.periodOffset)
        }
        self.periodKind = kind
        self.range = range
        self.customStart = range.start
        self.customEnd = max(range.end.addingTimeInterval(-86_400), range.start)
    }

    // MARK: - Derived state

    var settings: AppSettings { environment.settings }
    var formatter: MetricFormatter { environment.formatter }
    var periodFormatter: PeriodFormatter { environment.periodFormatter }

    var loadRequest: LoadRequest {
        LoadRequest(range: range, comparison: settings.comparisonMode, useMockData: settings.useMockData)
    }

    var rangeTitle: String {
        periodFormatter.rangeTitle(for: range)
    }

    var isCurrentPeriod: Bool {
        range.contains(environment.now())
    }

    var canStepForward: Bool {
        periodKind.isNavigable && !isCurrentPeriod
    }

    var canStepBackward: Bool {
        periodKind.isNavigable
    }

    var showsPermissionHint: Bool {
        !settings.useMockData && environment.healthKit.isAvailable && (stats?.isEmpty ?? false)
    }

    var healthAccessUnavailable: Bool {
        !environment.healthKit.isAvailable && !settings.useMockData
    }

    // MARK: - Navigation

    func select(_ kind: PeriodKind) {
        periodKind = kind
        selectedBucketIndex = nil
        if kind == .custom {
            range = environment.periodCalendar.customRange(start: customStart, end: customEnd)
        } else {
            range = environment.periodCalendar.range(for: kind, containing: environment.now())
        }
    }

    func applyCustomRange(start: Date, end: Date) {
        customStart = start
        customEnd = end
        periodKind = .custom
        selectedBucketIndex = nil
        range = environment.periodCalendar.customRange(start: start, end: end)
    }

    func step(by offset: Int) {
        guard periodKind.isNavigable else { return }
        selectedBucketIndex = nil
        range = environment.periodCalendar.offset(range, by: offset)
    }

    func goToNow() {
        selectedBucketIndex = nil
        if periodKind == .custom {
            let now = environment.now()
            customEnd = now
            customStart = environment.periodCalendar.calendar.date(byAdding: .day, value: -29, to: now) ?? now
            range = environment.periodCalendar.customRange(start: customStart, end: customEnd)
        } else {
            range = environment.periodCalendar.range(for: periodKind, containing: environment.now())
        }
    }

    func selectMetric(_ metric: Metric) {
        self.metric = metric
        selectedBucketIndex = nil
    }

    // MARK: - Loading

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let request = loadRequest

        if stats == nil {
            phase = .loading
        }

        do {
            let source: any HealthDataProviding = request.useMockData ? environment.mock : environment.healthKit

            if !request.useMockData {
                await requestAuthorizationIfNeeded()
            }

            let comparisonRange = environment.periodCalendar.comparisonRange(for: request.range, mode: request.comparison)
            let window = DateInterval(
                start: min(request.range.start, comparisonRange.start),
                end: max(request.range.end, comparisonRange.end)
            )

            let stepGranularity: StepGranularity = environment.periodCalendar.granularity(for: request.range) == .hour
                ? .hour
                : .day
            async let activitiesTask = source.activities(in: window)
            async let stepsTask = source.stepSamples(in: window, granularity: stepGranularity)
            async let distanceTask = source.distanceSamples(in: window, granularity: stepGranularity)
            async let elevationTask = source.elevationSamples(in: window, granularity: stepGranularity)
            let (activities, steps, distance, elevation) = try await (
                activitiesTask,
                stepsTask,
                distanceTask,
                elevationTask
            )

            guard generation == loadGeneration else { return }

            // Steps and distance inside the workouts come from sample queries
            // scoped to the workout windows: HealthKit does not attach step
            // statistics to workouts.
            let windows = activities.map { DateInterval(start: $0.start, end: $0.end) }
            async let workoutStepsTask = source.workoutQuantitySamples(
                in: window,
                kind: .steps,
                within: windows,
                granularity: stepGranularity
            )
            async let workoutDistanceTask = source.workoutQuantitySamples(
                in: window,
                kind: .distance,
                within: windows,
                granularity: stepGranularity
            )
            let (workoutSteps, workoutDistance) = try await (workoutStepsTask, workoutDistanceTask)

            guard generation == loadGeneration else { return }

            let samples = HealthSamples(
                activities: activities,
                steps: steps,
                distance: distance,
                elevation: elevation,
                workoutSteps: workoutSteps,
                workoutDistance: workoutDistance
            )

            let aggregated = StatsAggregator(periodCalendar: environment.periodCalendar).stats(
                for: request.range,
                samples: samples,
                comparison: request.comparison,
                now: environment.now()
            )

            self.aggregated = aggregated

            if let selection = ScreenshotRoute.selection, ScreenshotRoute.isActive {
                let stats = aggregated.stats(for: dataScope)
                switch selection {
                case .peak:
                    self.selectedBucketIndex = stats.buckets
                        .max { $0.totals.value(for: metric) < $1.totals.value(for: metric) }?
                        .bucket.index
                case .index(let index):
                    self.selectedBucketIndex = min(max(0, index), max(0, stats.buckets.count - 1))
                }
            }
            self.recentActivities = activities
                .filter { request.range.contains($0.start) }
                .sorted { $0.start > $1.start }
            phase = .loaded
        } catch is CancellationError {
            return
        } catch let error as HealthDataError where error.isAuthorizationNotDetermined {
            guard generation == loadGeneration else { return }
            phase = .needsAuthorization
        } catch {
            guard generation == loadGeneration else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    /// Shows the system Health permission sheet the first time the dashboard loads
    /// with real data. HealthKit returns `shouldRequest` only until the user has
    /// been asked, so this never nags.
    private func requestAuthorizationIfNeeded() async {
        guard environment.healthKit.isAvailable, !isRequestingAuthorization else { return }

        let status = try? await environment.healthKit.authorizationRequestStatus()
        guard status == .shouldRequest else { return }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        try? await environment.healthKit.requestAuthorization()
    }

    func requestHealthAccess() async {
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }

        do {
            try await environment.healthKit.requestAuthorization()
            settings.useMockData = false
            await load()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
