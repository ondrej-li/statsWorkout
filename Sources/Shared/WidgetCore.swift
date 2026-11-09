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

    init(calendar: Calendar = .autoupdatingCurrent, store: any HealthCacheStoring = FileHealthCacheStore()) {
        self.calendar = calendar
        self.store = store
    }

    func load(configuration: WidgetFilters, now: Date = Date()) async -> WidgetStats {
        let configuration = configuration.validates()
        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = Self.range(for: configuration, periodCalendar: periodCalendar, now: now)

        guard let cache = await store.load() else {
            return WidgetStats(range: range, content: .needsApp, syncedAt: nil)
        }

        let comparisonRange = periodCalendar.comparisonRange(for: range, mode: configuration.comparison)
        let window = DateInterval(
            start: min(range.start, comparisonRange.start),
            end: max(range.end, comparisonRange.end)
        )
        let samples = cache.samples(in: window)

        guard !samples.isEmpty else {
            return WidgetStats(range: range, content: .empty, syncedAt: cache.lastSyncedAt)
        }

        let aggregated = StatsAggregator(periodCalendar: periodCalendar).stats(
            for: range,
            samples: samples,
            comparison: configuration.comparison,
            now: now
        )
        return WidgetStats(
            range: range,
            content: .ready(aggregated.stats(for: configuration.scope)),
            syncedAt: cache.lastSyncedAt
        )
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
        let bucketCount = Double(max(buckets.count, 1))

        func spread(_ factor: Double) -> MetricTotals {
            MetricTotals(
                steps: 9_140 / bucketCount * factor,
                distanceMeters: 7_240 / bucketCount * factor,
                elevationGainMeters: 96 / bucketCount * factor,
                exerciseDuration: 3_480 / bucketCount * factor,
                activityCount: 0
            )
        }

        return PeriodStats(
            range: range,
            comparisonRange: comparisonRange,
            comparisonMode: filters.comparison,
            granularity: periodCalendar.granularity(for: range),
            buckets: buckets.enumerated().map { index, bucket in
                // A gentle wave, so the chart has a readable shape.
                let wave = 0.55 + 0.45 * abs(sin(Double(index) * 0.8))
                return BucketStats(bucket: bucket, totals: spread(wave))
            },
            totals: MetricTotals(
                steps: 9_140,
                distanceMeters: 7_240,
                elevationGainMeters: 96,
                exerciseDuration: 3_480,
                activityCount: 3
            ),
            comparisonTotals: MetricTotals(
                steps: 7_490,
                distanceMeters: 5_930,
                elevationGainMeters: 78,
                exerciseDuration: 2_850,
                activityCount: 2
            ),
            previousSeries: previousBuckets.map { _ in spread(0.4) },
            elapsedBucketCount: max(buckets.count, 1),
            isCurrentPeriod: true,
            elapsedFraction: 1
        )
    }
}
