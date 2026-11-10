import Foundation

/// Everything the widget's configuration screen can set, in the app's own
/// types.
///
/// This lives in the shared layer rather than the extension so the resolution
/// rules — which period, which metrics — are unit-testable without WidgetKit.
struct WidgetFilters: Equatable, Sendable {
    var period: PeriodKind = .month
    /// How many periods back. `0` is the current one.
    var periodsAgo: Int = 0
    var customStart: Date?
    var customEnd: Date?
    var scope: DataScope = .all
    var comparison: ComparisonMode = .previousPeriod
    var primaryMetric: Metric = .steps
    /// Shown in the spare room: after the main metric, as far as the size allows.
    var extraMetrics: [Metric] = [.distance, .exerciseDuration, .elevationGain, .activityCount]

    func validates() -> WidgetFilters {
        var copy = self
        copy.periodsAgo = max(0, min(periodsAgo, 120))
        // The main metric is never repeated below it, and a metric chosen twice
        // would draw two identical rows.
        var seen: Set<Metric> = [primaryMetric]
        copy.extraMetrics = extraMetrics.filter { seen.insert($0).inserted }
        return copy
    }
}

/// Which metrics a widget shows, given how many rows it has room for.
enum WidgetMetricSelection {
    static func metrics(for configuration: WidgetFilters, capacity: Int) -> [Metric] {
        let ordered = [configuration.primaryMetric] + configuration.extraMetrics.filter { $0 != configuration.primaryMetric }
        return Array(ordered.prefix(max(1, capacity)))
    }
}

/// The window a widget shows, and what it found in it.
struct WidgetStats: Sendable {
    enum Content: Sendable {
        case ready(PeriodStats)
        case needsApp
        case empty
    }

    let range: PeriodRange
    let content: Content
    let syncedAt: Date?

    var periodStats: PeriodStats? {
        if case .ready(let stats) = content { return stats }
        return nil
    }
}

/// Reads the app's cached day totals from the shared container and aggregates
/// them the same way the dashboard does.
///
/// The widget deliberately does not query HealthKit: that would mean its own
/// authorization sheet and a cold query inside a snapshot, and a widget that asks
/// for permission before showing a number is a bad widget. The app already keeps
/// 400 days of daily roll-ups in the App Group container; this reads them.
struct WidgetDataSource: Sendable {
    let calendar: Calendar
    let store: any HealthCacheStoring
    /// When set, the widget reads Apple Health directly — the only way it can be
    /// current while the user is walking or working out with the app closed.
    /// `nil` reads the app's cache instead.
    let liveSource: (any HealthDataProviding)?
    let sourceKey: String

    init(
        calendar: Calendar = .autoupdatingCurrent,
        store: any HealthCacheStoring = FileHealthCacheStore(),
        liveSource: (any HealthDataProviding)? = nil,
        sourceKey: String = "healthkit"
    ) {
        self.calendar = calendar
        self.store = store
        self.liveSource = liveSource
        self.sourceKey = sourceKey
    }

    func load(configuration: WidgetFilters, now: Date = Date()) async -> WidgetStats {
        let configuration = configuration.validates()
        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = Self.range(for: configuration, periodCalendar: periodCalendar, now: now)
        let comparisonRange = periodCalendar.comparisonRange(for: range, mode: configuration.comparison)
        let window = DateInterval(
            start: min(range.start, comparisonRange.start),
            end: max(range.end, comparisonRange.end)
        )

        // A day or 24-hour widget needs hourly resolution, which the daily cache
        // cannot provide; everything else is fine either way.
        let granularity: StepGranularity = periodCalendar.granularity(for: range) == .hour ? .hour : .day

        if let liveSource {
            if let samples = try? await load(
                window: window,
                granularity: granularity,
                source: liveSource,
                now: now
            ), !samples.isEmpty {
                return WidgetStats(
                    range: range,
                    content: .ready(aggregate(samples, range: range, configuration: configuration, periodCalendar: periodCalendar, now: now)),
                    syncedAt: now
                )
            }
        }

        guard let cache = await store.load() else {
            return WidgetStats(range: range, content: .needsApp, syncedAt: nil)
        }

        let samples = cache.samples(in: window)
        guard !samples.isEmpty else {
            return WidgetStats(range: range, content: .empty, syncedAt: cache.lastSyncedAt)
        }

        return WidgetStats(
            range: range,
            content: .ready(aggregate(samples, range: range, configuration: configuration, periodCalendar: periodCalendar, now: now)),
            syncedAt: cache.lastSyncedAt
        )
    }

    /// Reads Health through the same coordinator the app uses, so the widget's
    /// query also refreshes the shared cache the app reads next time.
    private func load(
        window: DateInterval,
        granularity: StepGranularity,
        source: any HealthDataProviding,
        now: Date
    ) async throws -> HealthSamples {
        try await HealthSyncCoordinator(store: store, calendar: calendar).loadSamples(
            for: window,
            granularity: granularity,
            source: source,
            sourceKey: sourceKey,
            now: now
        )
    }

    private func aggregate(
        _ samples: HealthSamples,
        range: PeriodRange,
        configuration: WidgetFilters,
        periodCalendar: PeriodCalendar,
        now: Date
    ) -> PeriodStats {
        StatsAggregator(periodCalendar: periodCalendar)
            .stats(for: range, samples: samples, comparison: configuration.comparison, now: now)
            .stats(for: configuration.scope)
    }

    /// The window on screen: the current period, or `periodsAgo` back from it.
    static func range(
        for configuration: WidgetFilters,
        periodCalendar: PeriodCalendar,
        now: Date
    ) -> PeriodRange {
        let base: PeriodRange
        if configuration.period == .custom,
           let start = configuration.customStart,
           let end = configuration.customEnd {
            base = periodCalendar.customRange(start: start, end: end)
        } else {
            base = periodCalendar.range(for: configuration.period, containing: now)
        }
        return configuration.periodsAgo == 0
            ? base
            : periodCalendar.offset(base, by: -configuration.periodsAgo)
    }
}

/// Sample numbers for the widget gallery and the placeholder state.
///
/// Deliberately synthetic: a preview must never show a real person's activity,
/// and a widget has to look right before the app has ever written a cache.
enum WidgetPlaceholder {
    static func stats(
        for configuration: WidgetFilters,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> PeriodStats {
        let filters = configuration.validates()
        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = WidgetDataSource.range(for: filters, periodCalendar: periodCalendar, now: now)
        let buckets = periodCalendar.buckets(for: range)
        let comparisonRange = periodCalendar.comparisonRange(for: range, mode: filters.comparison)
        let previousBuckets = periodCalendar.buckets(for: comparisonRange)
        let hourly = periodCalendar.granularity(for: range) == .hour

        // Plausible per-bucket numbers, so the gallery shows a readable chart and
        // a realistic average rather than totals divided by a bucket count.
        func totals(forBucket index: Int) -> MetricTotals {
            let wave = 0.55 + 0.45 * abs(sin(Double(index) * 0.8))
            return MetricTotals(
                steps: (hourly ? 420 : 8_400) * wave,
                distanceMeters: (hourly ? 380 : 7_600) * wave,
                elevationGainMeters: (hourly ? 2 : 22) * wave,
                exerciseDuration: (hourly ? 150 : 3_000) * wave,
                activityCount: 0
            )
        }

        let bucketStats = buckets.enumerated().map { index, bucket in
            BucketStats(bucket: bucket, totals: totals(forBucket: index))
        }
        let summed = bucketStats.reduce(MetricTotals()) { $0 + $1.totals }
        let periodTotals = MetricTotals(
            steps: summed.steps,
            distanceMeters: summed.distanceMeters,
            elevationGainMeters: summed.elevationGainMeters,
            exerciseDuration: summed.exerciseDuration,
            activityCount: max(1, buckets.count / 9)
        )

        return PeriodStats(
            range: range,
            comparisonRange: comparisonRange,
            comparisonMode: filters.comparison,
            granularity: periodCalendar.granularity(for: range),
            buckets: bucketStats,
            totals: periodTotals,
            comparisonTotals: MetricTotals(
                steps: periodTotals.steps * 0.82,
                distanceMeters: periodTotals.distanceMeters * 0.82,
                elevationGainMeters: periodTotals.elevationGainMeters * 0.82,
                exerciseDuration: periodTotals.exerciseDuration * 0.82,
                activityCount: max(0, periodTotals.activityCount - 1)
            ),
            previousSeries: previousBuckets.enumerated().map { index, _ in totals(forBucket: index) },
            elapsedBucketCount: max(buckets.count, 1),
            isCurrentPeriod: true,
            elapsedFraction: 1
        )
    }
}
