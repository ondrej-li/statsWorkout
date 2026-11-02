import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    struct LoadRequest: Hashable {
        let range: PeriodRange
        let comparison: ComparisonMode
        let useMockData: Bool
    }

    var periodKind: PeriodKind
    var range: PeriodRange
    var metric: Metric = .steps
    var selectedBucketIndex: Int?
    var phase: Phase = .loading
    var stats: PeriodStats?
    var recentActivities: [ActivitySample] = []
    var isRequestingAuthorization = false
    var customStart: Date
    var customEnd: Date

    private let environment: AppEnvironment
    private var loadGeneration = 0

    init(environment: AppEnvironment) {
        self.environment = environment
        let now = environment.now()
        let kind = environment.settings.preferredPeriod
        let range = environment.periodCalendar.range(for: kind, containing: now)
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
            let comparisonRange = environment.periodCalendar.comparisonRange(for: request.range, mode: request.comparison)
            let window = DateInterval(
                start: min(request.range.start, comparisonRange.start),
                end: max(request.range.end, comparisonRange.end)
            )

            async let activitiesTask = source.activities(in: window)
            async let stepsTask = source.dailySteps(in: window)
            let (activities, steps) = try await (activitiesTask, stepsTask)

            guard generation == loadGeneration else { return }

            let stats = StatsAggregator(periodCalendar: environment.periodCalendar).stats(
                for: request.range,
                activities: activities,
                steps: steps,
                comparison: request.comparison,
                now: environment.now()
            )

            self.stats = stats
            self.recentActivities = activities
                .filter { request.range.contains($0.start) }
                .sorted { $0.start > $1.start }
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            phase = .failed(error.localizedDescription)
        }
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
