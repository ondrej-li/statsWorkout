import Foundation
import Testing
@testable import StatsWorkout

@Suite("Stats aggregation")
struct StatsAggregatorTests {
    private let calendar = TestSupport.calendar()
    private var period: PeriodCalendar { TestSupport.period(calendar) }
    private var aggregator: StatsAggregator { StatsAggregator(periodCalendar: period) }

    private var november: PeriodRange {
        period.range(for: .month, containing: TestSupport.date(calendar, 2026, 11, 15))
    }

    private func activity(
        _ day: Int,
        month: Int = 11,
        hour: Int = 8,
        minutes: Double = 60,
        distance: Double? = 10_000,
        elevation: Double? = 120,
        steps: Double? = nil
    ) -> ActivitySample {
        let start = TestSupport.date(calendar, 2026, month, day, hour)
        return ActivitySample(
            kind: .running,
            start: start,
            end: start.addingTimeInterval(minutes * 60),
            distanceMeters: distance,
            elevationGainMeters: elevation,
            stepCount: steps,
            activeEnergyKilocalories: 500
        )
    }

    private func steps(_ day: Int, _ count: Double) -> StepSample {
        let start = TestSupport.date(calendar, 2026, 11, day)
        return StepSample(start: start, end: start.addingTimeInterval(86_400), count: count)
    }

    private func daySample(_ day: Int, _ value: Double) -> QuantitySample {
        let start = TestSupport.date(calendar, 2026, 11, day)
        return QuantitySample(start: start, end: start.addingTimeInterval(86_400), value: value)
    }

    private func stats(
        _ range: PeriodRange,
        activities: [ActivitySample] = [],
        steps: [StepSample] = [],
        distance: [QuantitySample] = [],
        elevation: [QuantitySample] = [],
        workoutSteps: [QuantitySample] = [],
        workoutDistance: [QuantitySample] = [],
        now: Date,
        scope: DataScope = .all
    ) -> PeriodStats {
        let samples = HealthSamples(
            activities: activities,
            steps: steps,
            distance: distance,
            elevation: elevation,
            workoutSteps: workoutSteps,
            workoutDistance: workoutDistance
        )
        return aggregator.stats(for: range, samples: samples, now: now).stats(for: scope)
    }

    private func sample(_ day: Int, _ value: Double, month: Int = 11) -> QuantitySample {
        let start = TestSupport.date(calendar, 2026, month, day)
        return QuantitySample(start: start, end: start.addingTimeInterval(86_400), value: value)
    }

    @Test("Activities scope uses the samples recorded inside workouts")
    func activitiesScope() {
        let stats = stats(
            november,
            activities: [
                activity(3, distance: 10_000, elevation: 120),
                activity(10, minutes: 30, distance: 5_000, elevation: 40),
                activity(10, hour: 18, distance: 10_000, elevation: 120)
            ],
            workoutSteps: [sample(3, 4_000), sample(10, 5_000)],
            workoutDistance: [sample(3, 10_000), sample(10, 15_000)],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .activities
        )

        let expectedDuration: TimeInterval = 60 * 60 * 2 + 30 * 60

        #expect(stats.totals.activityCount == 3)
        #expect(stats.totals.steps == 9_000)
        #expect(stats.totals.distanceMeters == 25_000)
        #expect(stats.totals.elevationGainMeters == 280)
        #expect(stats.totals.exerciseDuration == expectedDuration)
    }

    @Test("Workout steps come from samples, not from the workout statistics")
    func workoutStepsWithoutWorkoutStatistics() {
        // HealthKit does not attach step statistics to workouts, so a workout
        // arrives with a nil stepCount. Steps must still be reported.
        let stats = stats(
            november,
            activities: [activity(3, distance: 10_000, elevation: 0, steps: nil)],
            steps: [steps(3, 9_000)],
            workoutSteps: [sample(3, 6_400)],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .activities
        )

        #expect(stats.totals.steps == 6_400)
        #expect(stats.totals.activityCount == 1)
    }

    @Test("Workout statistics are the fallback when no samples are available")
    func workoutStatisticsFallback() {
        let stats = stats(
            november,
            activities: [activity(3, distance: 10_000, elevation: 0, steps: 5_500)],
            workoutSteps: [],
            workoutDistance: [],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .activities
        )

        #expect(stats.totals.steps == 5_500)
        #expect(stats.totals.distanceMeters == 10_000)
    }

    @Test("All-data scope uses continuous monitoring for steps, distance and elevation")
    func allDataScope() {
        let stats = stats(
            november,
            activities: [activity(3, distance: 5_000, elevation: 100, steps: 1_000)],
            steps: [steps(3, 8_000)],
            distance: [daySample(3, 12_000)],
            elevation: [daySample(3, 60)],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .all
        )

        #expect(stats.totals.steps == 8_000)
        #expect(stats.totals.distanceMeters == 12_000)
        // Elevation keeps the larger of the two sources.
        #expect(stats.totals.elevationGainMeters == 100)
        #expect(stats.totals.activityCount == 1)
        #expect(stats.totals.exerciseDuration == 3_600)
    }

    @Test("Both scopes are produced by a single aggregation pass")
    func bothScopes() {
        let samples = HealthSamples(
            activities: [activity(3, steps: 1_000)],
            steps: [steps(3, 8_000)],
            distance: [daySample(3, 12_000)]
        )
        let aggregated = aggregator.stats(
            for: november,
            samples: samples,
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(aggregated.activities.totals.steps == 1_000)
        #expect(aggregated.allData.totals.steps == 8_000)
        #expect(aggregated.stats(for: .activities) == aggregated.activities)
    }

    @Test("Each activity lands in its own day bucket")
    func bucketAssignment() {
        let stats = stats(
            november,
            activities: [activity(3), activity(10, hour: 18)],
            steps: [steps(4, 9_000)],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .all
        )

        #expect(stats.buckets.count == 30)
        #expect(stats.buckets[2].totals.activityCount == 1)  // 3 Nov
        #expect(stats.buckets[3].totals.steps == 9_000)      // 4 Nov
        #expect(stats.buckets[9].totals.activityCount == 1)  // 10 Nov
        #expect(stats.buckets[0].totals.isEmpty)
    }

    @Test("Hourly step samples land in the matching hour bucket")
    func hourlyStepBuckets() {
        let range = period.range(for: .day, containing: TestSupport.date(calendar, 2026, 11, 4, 12))
        let hour = TestSupport.date(calendar, 2026, 11, 4, 9)
        let sample = StepSample(start: hour, end: hour.addingTimeInterval(3_600), count: 700)

        let stats = stats(range, steps: [sample], now: TestSupport.date(calendar, 2026, 11, 4, 13))

        #expect(stats.buckets.count == 24)
        #expect(stats.buckets[9].totals.steps == 700)
        #expect(stats.totals.steps == 700)
    }

    @Test("Comparison only counts the elapsed part of the previous period")
    func partialComparison() {
        let stats = stats(
            november,
            activities: [activity(5, distance: 10_000), activity(20, distance: 10_000)],
            steps: [steps(5, 10_000), steps(25, 10_000)],
            now: TestSupport.date(calendar, 2026, 11, 13)
        )

        #expect(stats.comparisonTotals.isEmpty)  // no October samples were supplied
        #expect(stats.elapsedBucketCount == 13)
        #expect(stats.totals.activityCount == 2)
        #expect(stats.previousSeries.count == 30)
    }

    @Test("Delta compares against the same elapsed window")
    func delta() {
        let october = activity(6, month: 10, distance: 10_000, steps: 2_000)
        let stats = stats(
            november,
            activities: [activity(6, distance: 15_000, steps: 5_000), october],
            now: TestSupport.date(calendar, 2026, 11, 20),
            scope: .activities
        )

        #expect(stats.comparisonTotals.activityCount == 1)
        #expect(stats.delta(of: .distance) == 0.5)
        #expect(stats.delta(of: .steps) == 1.5)
    }

    @Test("Cumulative series grows monotonically")
    func cumulativeSeries() {
        let range = period.range(for: .week, containing: TestSupport.date(calendar, 2026, 11, 4))
        let stats = stats(
            range,
            activities: [activity(3, distance: 5_000), activity(5, distance: 7_000)],
            steps: [steps(3, 1_000), steps(4, 2_000)],
            now: TestSupport.date(calendar, 2026, 11, 8),
            scope: .activities
        )

        let cumulative = stats.cumulativeSeries(of: .distance)
        #expect(cumulative.count == 7)
        #expect(cumulative.last == 12_000)
        #expect(zip(cumulative, cumulative.dropFirst()).allSatisfy { $0 <= $1 })

        let previous = stats.previousCumulativeSeries(of: .distance)
        #expect(previous.count == 7)
        #expect(previous.allSatisfy { $0 == 0 })
    }

    @Test("Samples outside the range are ignored")
    func ignoresOutOfRangeSamples() {
        let octoberActivity = activity(20, month: 10)
        let octoberDay = TestSupport.date(calendar, 2026, 10, 20)
        let octoberSteps = StepSample(
            start: octoberDay,
            end: octoberDay.addingTimeInterval(86_400),
            count: 7_000
        )

        let stats = stats(
            november,
            activities: [activity(2), octoberActivity],
            steps: [steps(2, 5_000), octoberSteps],
            now: TestSupport.date(calendar, 2026, 11, 20)
        )

        #expect(stats.totals.activityCount == 1)
        #expect(stats.totals.steps == 5_000)
    }
}
