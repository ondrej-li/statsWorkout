import Foundation
import Testing
@testable import StatsWorkout

@Suite("Stats aggregation")
struct StatsAggregatorTests {
    private let calendar = TestSupport.calendar()
    private var period: PeriodCalendar { TestSupport.period(calendar) }
    private var aggregator: StatsAggregator { StatsAggregator(periodCalendar: period) }

    private func activity(
        _ day: Int,
        hour: Int = 8,
        minutes: Double = 60,
        distance: Double? = 10_000,
        elevation: Double? = 120
    ) -> ActivitySample {
        let start = TestSupport.date(calendar, 2026, 11, day, hour)
        return ActivitySample(
            kind: .running,
            start: start,
            end: start.addingTimeInterval(minutes * 60),
            distanceMeters: distance,
            elevationGainMeters: elevation,
            activeEnergyKilocalories: 500
        )
    }

    private func steps(_ day: Int, _ count: Double) -> StepSample {
        let start = TestSupport.date(calendar, 2026, 11, day)
        return StepSample(start: start, end: start.addingTimeInterval(86_400), count: count)
    }

    @Test("Totals sum workouts and all-day steps")
    func totals() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))
        let stats = aggregator.stats(
            for: range,
            activities: [activity(3), activity(10, minutes: 30, distance: 5_000, elevation: 40), activity(10, hour: 18)],
            steps: [steps(3, 8_000), steps(4, 12_000), steps(10, 6_000)],
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(stats.totals.activityCount == 3)
        #expect(stats.totals.steps == 26_000)
        #expect(stats.totals.distanceMeters == 25_000)
        #expect(stats.totals.elevationGainMeters == 280)
        #expect(stats.totals.exerciseDuration == 60 * 60 * 2 + 30 * 60)
    }

    @Test("Each activity lands in its own day bucket")
    func bucketAssignment() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))
        let stats = aggregator.stats(
            for: range,
            activities: [activity(3), activity(10, hour: 18)],
            steps: [steps(4, 9_000)],
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(stats.buckets.count == 30)
        #expect(stats.buckets[2].totals.activityCount == 1)  // 3 Nov
        #expect(stats.buckets[3].totals.steps == 9_000)      // 4 Nov
        #expect(stats.buckets[9].totals.activityCount == 1)  // 10 Nov
        #expect(stats.buckets[0].totals.isEmpty)
    }

    @Test("Comparison only counts the elapsed part of the previous period")
    func partialComparison() {
        var previousMonth = Calendar(identifier: .gregorian)
        previousMonth.timeZone = TimeZone(identifier: "UTC")!
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))

        // 12 days elapsed: 1 Nov 00:00 -> 13 Nov 00:00
        let now = TestSupport.date(calendar, 2026, 11, 13)
        let stats = aggregator.stats(
            for: range,
            activities: [
                activity(5, distance: 10_000),
                activity(20, distance: 10_000)
            ],
            steps: [steps(5, 10_000), steps(25, 10_000)],
            now: now
        )

        // Previous period = October. Its first 12 days are used for comparison.
        #expect(stats.comparisonTotals.isEmpty) // no October samples were supplied
        #expect(stats.elapsedBucketCount == 13)
        #expect(stats.totals.activityCount == 2)
        #expect(stats.previousSeries.count == 30)
    }

    @Test("Delta compares against the same elapsed window")
    func delta() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))
        let octoberRun = ActivitySample(
            kind: .running,
            start: TestSupport.date(calendar, 2026, 10, 6, 8),
            end: TestSupport.date(calendar, 2026, 10, 6, 9),
            distanceMeters: 10_000
        )

        let stats = aggregator.stats(
            for: range,
            activities: [activity(6, distance: 15_000), octoberRun],
            steps: [],
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(stats.comparisonTotals.activityCount == 1)
        #expect(stats.delta(of: .distance) == 0.5)
        #expect(stats.delta(of: .steps) == nil)
    }

    @Test("Cumulative series grows monotonically")
    func cumulativeSeries() {
        let range = period.range(for: .week, containing: TestSupport.date(calendar, 2026, 11, 4))
        let stats = aggregator.stats(
            for: range,
            activities: [activity(3, distance: 5_000), activity(5, distance: 7_000)],
            steps: [steps(3, 1_000), steps(4, 2_000)],
            now: TestSupport.date(calendar, 2026, 11, 8)
        )

        let cumulative = stats.cumulativeSeries(of: .distance)
        #expect(cumulative.count == 7)
        #expect(cumulative.last == 12_000)
        #expect(zip(cumulative, cumulative.dropFirst()).allSatisfy { $0 <= $1 })

        let previous = stats.previousCumulativeSeries(of: .distance)
        #expect(previous.count == 7)
        #expect(previous.allSatisfy { $0 == 0 })
    }

    @Test("Hourly step samples land in the matching hour bucket")
    func hourlyStepBuckets() {
        let range = period.range(for: .day, containing: TestSupport.date(calendar, 2026, 11, 4, 12))
        let hour = TestSupport.date(calendar, 2026, 11, 4, 9)
        let sample = StepSample(start: hour, end: hour.addingTimeInterval(3_600), count: 700)

        let stats = aggregator.stats(
            for: range,
            activities: [],
            steps: [sample],
            now: TestSupport.date(calendar, 2026, 11, 4, 13)
        )

        #expect(stats.buckets.count == 24)
        #expect(stats.buckets[9].totals.steps == 700)
        #expect(stats.totals.steps == 700)
    }

    @Test("Samples outside the range are ignored")
    func ignoresOutOfRangeSamples() {
        let range = period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))
        let octoberActivity = ActivitySample(
            kind: .cycling,
            start: TestSupport.date(calendar, 2026, 10, 20, 9),
            end: TestSupport.date(calendar, 2026, 10, 20, 10)
        )
        let octoberDay = TestSupport.date(calendar, 2026, 10, 20)
        let octoberSteps = StepSample(
            start: octoberDay,
            end: octoberDay.addingTimeInterval(86_400),
            count: 7_000
        )

        let stats = aggregator.stats(
            for: range,
            activities: [activity(2), octoberActivity],
            steps: [steps(2, 5_000), octoberSteps],
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(stats.totals.activityCount == 1)
        #expect(stats.totals.steps == 5_000)
    }
}
