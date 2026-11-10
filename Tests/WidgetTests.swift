import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import StatsWorkout

@Suite("Widget filters")
struct WidgetFiltersTests {
    private let calendar = TestSupport.calendar()

    @Test("Every app period can be configured, including a custom range")
    func periods() {
        // The widget offers exactly the app's period kinds, so nothing available
        // on the dashboard is missing from the widget's settings.
        let expected: Set<PeriodKind> = [.day, .last24Hours, .week, .month, .quarter, .year, .custom]
        #expect(Set(PeriodKind.allCases) == expected)
    }

    @Test("A period window matches the dashboard's")
    func rangeMatchesDashboard() {
        let now = TestSupport.date(calendar, 2026, 11, 9, 10)
        let periodCalendar = PeriodCalendar(calendar: calendar)

        for kind in [PeriodKind.day, .week, .month, .quarter, .year, .last24Hours] {
            let widgetRange = WidgetDataSource.range(
                for: WidgetFilters(period: kind),
                periodCalendar: periodCalendar,
                now: now
            )
            let dashboardRange = periodCalendar.range(for: kind, containing: now)
            #expect(widgetRange == dashboardRange, "\(kind) differs")
        }
    }

    @Test("Stepping back N periods lands on the same window as the app's chevrons")
    func periodsAgo() {
        let now = TestSupport.date(calendar, 2026, 11, 9, 10)
        let periodCalendar = PeriodCalendar(calendar: calendar)

        for periodsAgo in 1...3 {
            let widgetRange = WidgetDataSource.range(
                for: WidgetFilters(period: .month, periodsAgo: periodsAgo),
                periodCalendar: periodCalendar,
                now: now
            )
            var expected = periodCalendar.range(for: .month, containing: now)
            for _ in 0..<periodsAgo { expected = periodCalendar.offset(expected, by: -1) }
            #expect(widgetRange.start == expected.start)
            #expect(widgetRange.end == expected.end)
        }
    }

    @Test("A custom range is honoured, and stepped back as a block")
    func customRange() {
        let from = TestSupport.date(calendar, 2026, 9, 1)
        let to = TestSupport.date(calendar, 2026, 9, 10)
        let periodCalendar = PeriodCalendar(calendar: calendar)

        let range = WidgetDataSource.range(
            for: WidgetFilters(period: .custom, customStart: from, customEnd: to),
            periodCalendar: periodCalendar,
            now: TestSupport.date(calendar, 2026, 11, 9)
        )
        #expect(range.start == periodCalendar.customRange(start: from, end: to).start)
        #expect(range.dayCount(in: calendar) == 10)

        let earlier = WidgetDataSource.range(
            for: WidgetFilters(period: .custom, periodsAgo: 1, customStart: from, customEnd: to),
            periodCalendar: periodCalendar,
            now: TestSupport.date(calendar, 2026, 11, 9)
        )
        #expect(earlier.dayCount(in: calendar) == 10)
        #expect(earlier.end <= range.start)
    }

    @Test("A custom range without dates falls back to the current period")
    func customWithoutDates() {
        let now = TestSupport.date(calendar, 2026, 11, 9, 10)
        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = WidgetDataSource.range(
            for: WidgetFilters(period: .custom),
            periodCalendar: periodCalendar,
            now: now
        )
        #expect(range == periodCalendar.range(for: .custom, containing: now))
    }

    @Test("Filters are validated: no negative offsets, no duplicate metrics")
    func validation() {
        let filters = WidgetFilters(
            periodsAgo: -5,
            primaryMetric: .steps,
            extraMetrics: [.steps, .distance, .distance]
        ).validates()

        #expect(filters.periodsAgo == 0)
        #expect(filters.extraMetrics == [.distance])
        #expect(WidgetFilters(periodsAgo: 9_999).validates().periodsAgo == 120)
    }
}

@Suite("Widget metric selection")
struct WidgetMetricSelectionTests {
    @Test("Each size shows as many metrics as it has room for, main metric first")
    func capacities() {
        let filters = WidgetFilters(
            primaryMetric: .distance,
            extraMetrics: [.steps, .exerciseDuration, .elevationGain, .activityCount]
        )

        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 1) == [.distance])
        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 3) == [.distance, .steps, .exerciseDuration])
        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 5)
            == [.distance, .steps, .exerciseDuration, .elevationGain, .activityCount])
    }

    @Test("A capacity larger than the selection is not padded")
    func noPadding() {
        let filters = WidgetFilters(primaryMetric: .steps, extraMetrics: [.distance])
        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 5) == [.steps, .distance])
    }

    @Test("The main metric is never repeated in the extras")
    func noDuplicates() {
        let filters = WidgetFilters(primaryMetric: .steps, extraMetrics: [.steps, .distance]).validates()
        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 5) == [.steps, .distance])
    }

    @Test("At least one metric always shows, even with a capacity of zero")
    func minimum() {
        let filters = WidgetFilters(primaryMetric: .steps, extraMetrics: [])
        #expect(WidgetMetricSelection.metrics(for: filters, capacity: 0) == [.steps])
    }
}

@Suite("Widget data")
@MainActor
struct WidgetDataSourceTests {
    private let calendar = TestSupport.calendar(timeZone: "Europe/Prague")

    private func cache(now: Date) -> HealthSampleCache {
        let start = calendar.date(byAdding: .day, value: -40, to: now)!
        let interval = DateInterval(start: start, end: now)

        let activities = MockHealthData.activities(in: interval, calendar: calendar, seed: 0x5EED, now: now)
        let steps = MockHealthData.dailySteps(in: interval, calendar: calendar, seed: 0x5EED, now: now)
        let distance = MockHealthData.distanceSamples(
            in: interval, granularity: .day, calendar: calendar, seed: 0x5EED, now: now
        )
        let elevation = MockHealthData.elevationSamples(
            in: interval, granularity: .day, calendar: calendar, seed: 0x5EED, now: now
        )

        var cache = HealthSampleCache()
        cache.sourceKey = "mock"
        cache.lastSyncedAt = now
        // Build the days through the cache's own merge, so this exercises the
        // real writing path rather than a hand-made fixture.
        cache.merge(
            WidgetDataSourceTests.days(from: steps, distance: distance, elevation: elevation, calendar: calendar),
            activities: activities,
            covering: interval
        )
        return cache
    }

    /// Collapses the per-sample series into the daily roll-up the cache stores.
    static func days(
        from steps: [StepSample],
        distance: [QuantitySample],
        elevation: [QuantitySample],
        calendar: Calendar
    ) -> [CachedDay] {
        var byDay: [Date: CachedDay] = [:]
        for sample in steps {
            let day = calendar.startOfDay(for: sample.start)
            byDay[day, default: CachedDay(day: day)].steps += sample.count
        }
        for sample in distance {
            let day = calendar.startOfDay(for: sample.start)
            byDay[day, default: CachedDay(day: day)].distanceMeters += sample.value
        }
        for sample in elevation {
            let day = calendar.startOfDay(for: sample.start)
            byDay[day, default: CachedDay(day: day)].elevationMeters += sample.value
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    @Test("A widget with no cache asks the user to open the app")
    func needsApp() async {
        let source = WidgetDataSource(calendar: calendar, store: InMemoryHealthCacheStore())
        let result = await source.load(configuration: WidgetFilters(period: .month))
        if case .needsApp = result.content {} else {
            Issue.record("expected needsApp, got \(result.content)")
        }
        #expect(result.syncedAt == nil)
    }

    @Test("A populated cache produces the same totals as the dashboard")
    func matchesDashboard() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        let built = cache(now: now)
        await store.save(built)

        let filters = WidgetFilters(period: .month, scope: .all)
        let widget = await WidgetDataSource(calendar: calendar, store: store).load(configuration: filters, now: now)
        let stats = try? #require(widget.periodStats)

        // The dashboard path, with the same cache and the same aggregator.
        let periodCalendar = PeriodCalendar(calendar: calendar)
        let range = periodCalendar.range(for: .month, containing: now)
        let comparison = periodCalendar.comparisonRange(for: range, mode: .previousPeriod)
        let samples = built.samples(in: DateInterval(start: comparison.start, end: range.end))
        let expected = StatsAggregator(periodCalendar: periodCalendar)
            .stats(for: range, samples: samples, comparison: .previousPeriod, now: now)
            .allData

        #expect(stats?.totals == expected.totals)
        #expect(stats?.buckets.count == expected.buckets.count)
    }

    @Test("The Activities scope counts only workout samples")
    func activitiesScope() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        await store.save(cache(now: now))

        let source = WidgetDataSource(calendar: calendar, store: store)
        let all = await source.load(configuration: WidgetFilters(period: .month, scope: .all), now: now)
        let workouts = await source.load(configuration: WidgetFilters(period: .month, scope: .activities), now: now)

        let allSteps = try? #require(all.periodStats?.totals.steps)
        let workoutSteps = try? #require(workouts.periodStats?.totals.steps)
        #expect((allSteps ?? 0) > (workoutSteps ?? 0))
    }

    @Test("An empty window reports empty rather than zeros")
    func emptyWindow() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        await store.save(cache(now: now))

        // Well before the cache's 40 days.
        let result = await WidgetDataSource(calendar: calendar, store: store)
            .load(configuration: WidgetFilters(period: .month, periodsAgo: 12), now: now)
        if case .empty = result.content {} else {
            Issue.record("expected empty, got \(result.content)")
        }
    }

    @Test("A widget reads Apple Health live when it can, not just the cache")
    func liveSource() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        // No cache at all: only the live read can supply anything.
        let live = RecordingHealthDataSource(stepsPerDay: 9_000, calendar: calendar)

        let result = await WidgetDataSource(calendar: calendar, store: store, liveSource: live)
            .load(configuration: WidgetFilters(period: .week), now: now)

        let totals = try? #require(result.periodStats?.totals)
        #expect((totals?.steps ?? 0) > 0)
        #expect(await !live.dayWindows().isEmpty)
    }

    @Test("A day or 24-hour widget asks Health for hourly samples")
    func hourlyGranularity() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        let live = RecordingHealthDataSource(calendar: calendar)

        _ = await WidgetDataSource(calendar: calendar, store: store, liveSource: live)
            .load(configuration: WidgetFilters(period: .day), now: now)

        // The activities query always reports day granularity; the quantity
        // queries are the ones that must be hourly for a day widget.
        #expect(await live.hourWindows().count >= 3)
    }

    @Test("With no Health access the widget falls back to the app's cache")
    func cacheFallback() async {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let store = InMemoryHealthCacheStore()
        await store.save(cache(now: now))

        // A source that cannot answer: the cache is what is left.
        let result = await WidgetDataSource(calendar: calendar, store: store, liveSource: FailingHealthDataSource())
            .load(configuration: WidgetFilters(period: .month), now: now)

        let totals = try? #require(result.periodStats?.totals)
        #expect((totals?.steps ?? 0) > 0)
    }

    @Test("The placeholder has a readable shape and no real data")
    func placeholder() throws {
        let stats = WidgetPlaceholder.stats(
            for: WidgetFilters(period: .month),
            calendar: calendar,
            now: TestSupport.date(calendar, 2026, 11, 9, 12)
        )
        #expect(stats.totals.steps > 0)
        #expect(stats.totals.activityCount > 0)
        #expect(stats.buckets.count > 1)
        // A curve, not a flat line: the gallery should show a chart worth looking at.
        let values = stats.buckets.map(\.totals.steps)
        #expect(Set(values.map { Int($0.rounded()) }).count > 3)
        #expect(stats.delta(of: .steps) != nil)
    }
}

/// A source that is present but refuses every query, standing in for a user who
/// declined Health access.
struct FailingHealthDataSource: HealthDataProviding {
    var isAvailable: Bool { true }

    func authorizationRequestStatus() async throws -> HealthAuthorizationStatus { .unnecessary }
    func requestAuthorization() async throws {}
    func activities(in interval: DateInterval) async throws -> [ActivitySample] { throw HealthDataError.queryFailed("denied") }
    func stepSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [StepSample] {
        throw HealthDataError.queryFailed("denied")
    }
    func distanceSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        throw HealthDataError.queryFailed("denied")
    }
    func elevationSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        throw HealthDataError.queryFailed("denied")
    }
    func workoutQuantitySamples(
        in interval: DateInterval,
        kind: ContinuousQuantity,
        within windows: [DateInterval],
        granularity: StepGranularity
    ) async throws -> [QuantitySample] {
        throw HealthDataError.queryFailed("denied")
    }
    func workoutDetail(for activity: ActivitySample) async throws -> WorkoutDetail { WorkoutDetail() }
}
