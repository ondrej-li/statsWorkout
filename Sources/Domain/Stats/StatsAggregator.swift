import Foundation

/// Statistics for both data scopes, computed from one set of samples so the
/// dashboard can switch between them without another HealthKit round trip.
struct AggregatedStats: Sendable, Equatable {
    let allData: PeriodStats
    let activities: PeriodStats

    func stats(for scope: DataScope) -> PeriodStats {
        switch scope {
        case .all: return allData
        case .activities: return activities
        }
    }
}

/// Turns raw health samples into the numbers the dashboard renders.
///
/// Pure value type in / value type out: no HealthKit, no UI, no clock access —
/// `now` is injected so period comparisons are deterministic in tests.
struct StatsAggregator: Sendable {
    let periodCalendar: PeriodCalendar

    init(periodCalendar: PeriodCalendar = PeriodCalendar()) {
        self.periodCalendar = periodCalendar
    }

    func stats(
        for range: PeriodRange,
        samples: HealthSamples,
        comparison: ComparisonMode = .previousPeriod,
        now: Date
    ) -> AggregatedStats {
        let buckets = periodCalendar.buckets(for: range)
        let comparisonRange = periodCalendar.comparisonRange(for: range, mode: comparison)
        let previousBuckets = periodCalendar.buckets(for: comparisonRange)

        // Workouts do not carry step statistics, so steps inside a workout come
        // from sample queries scoped to the workout windows. Fall back to the
        // workout's own statistics when no such samples are available (no
        // permission, or a workout type Health never sampled).
        let hasWorkoutSteps = !samples.workoutSteps.isEmpty
        let hasWorkoutDistance = !samples.workoutDistance.isEmpty

        let current = aggregate(range: range, buckets: buckets, samples: samples)
        let previous = aggregate(range: comparisonRange, buckets: previousBuckets, samples: samples)

        func make(_ scope: DataScope) -> PeriodStats {
            makeStats(
                scope: scope,
                range: range,
                buckets: buckets,
                current: current,
                previous: previous,
                previousBuckets: previousBuckets,
                comparisonRange: comparisonRange,
                comparison: comparison,
                hasWorkoutSteps: hasWorkoutSteps,
                hasWorkoutDistance: hasWorkoutDistance,
                now: now
            )
        }

        return AggregatedStats(allData: make(.all), activities: make(.activities))
    }

    // MARK: - Private

    /// Per-bucket accumulators. Workout and continuous samples are kept apart so
    /// each scope can be derived without a second pass.
    private struct BucketTotals {
        var activities = MetricTotals.zero
        var workoutSteps: Double = 0
        var workoutDistance: Double = 0
        var continuousSteps: Double = 0
        var continuousDistance: Double = 0
        var continuousElevation: Double = 0

        func totals(
            for scope: DataScope,
            hasWorkoutSteps: Bool,
            hasWorkoutDistance: Bool
        ) -> MetricTotals {
            var totals = activities
            switch scope {
            case .activities:
                if hasWorkoutSteps { totals.steps = workoutSteps }
                if hasWorkoutDistance { totals.distanceMeters = workoutDistance }
            case .all:
                totals.steps = continuousSteps
                totals.distanceMeters = continuousDistance
                totals.elevationGainMeters = max(continuousElevation, activities.elevationGainMeters)
            }
            return totals
        }
    }

    private func aggregate(
        range: PeriodRange,
        buckets: [Bucket],
        samples: HealthSamples
    ) -> [BucketTotals] {
        guard !buckets.isEmpty else { return [] }

        var totals = Array(repeating: BucketTotals(), count: buckets.count)

        func bucketIndex(for date: Date) -> Int? {
            periodCalendar.bucketIndex(containing: max(date, range.start), in: buckets)
        }

        func isInside(_ start: Date, _ end: Date) -> Bool {
            end > range.start && start < range.end
        }

        for activity in samples.activities where isInside(activity.start, activity.end) {
            guard let index = bucketIndex(for: activity.start) else { continue }
            totals[index].activities.add(activity)
        }

        for sample in samples.workoutSteps where sample.value > 0 && isInside(sample.start, sample.end) {
            guard let index = bucketIndex(for: sample.start) else { continue }
            totals[index].workoutSteps += sample.value
        }

        for sample in samples.workoutDistance where sample.value > 0 && isInside(sample.start, sample.end) {
            guard let index = bucketIndex(for: sample.start) else { continue }
            totals[index].workoutDistance += sample.value
        }

        for sample in samples.steps where sample.count > 0 && isInside(sample.start, sample.end) {
            guard let index = bucketIndex(for: sample.start) else { continue }
            totals[index].continuousSteps += sample.count
        }

        for sample in samples.distance where sample.value > 0 && isInside(sample.start, sample.end) {
            guard let index = bucketIndex(for: sample.start) else { continue }
            totals[index].continuousDistance += sample.value
        }

        for sample in samples.elevation where sample.value > 0 && isInside(sample.start, sample.end) {
            guard let index = bucketIndex(for: sample.start) else { continue }
            totals[index].continuousElevation += sample.value
        }

        return totals
    }

    private func makeStats(
        scope: DataScope,
        range: PeriodRange,
        buckets: [Bucket],
        current: [BucketTotals],
        previous: [BucketTotals],
        previousBuckets: [Bucket],
        comparisonRange: PeriodRange,
        comparison: ComparisonMode,
        hasWorkoutSteps: Bool,
        hasWorkoutDistance: Bool,
        now: Date
    ) -> PeriodStats {
        func totals(_ buckets: [BucketTotals]) -> [MetricTotals] {
            buckets.map {
                $0.totals(
                    for: scope,
                    hasWorkoutSteps: hasWorkoutSteps,
                    hasWorkoutDistance: hasWorkoutDistance
                )
            }
        }

        let currentTotals = totals(current)
        let previousTotals = totals(previous)

        let previousSeries = (0..<buckets.count).map { index in
            index < previousTotals.count ? previousTotals[index] : .zero
        }

        let elapsed = max(0, min(now.timeIntervalSince(range.start), range.duration))
        let comparisonCutoff = min(comparisonRange.start.addingTimeInterval(elapsed), comparisonRange.end)
        var comparisonTotals = MetricTotals.zero
        for (index, bucket) in previousBuckets.enumerated() where bucket.start < comparisonCutoff {
            comparisonTotals = comparisonTotals + previousTotals[index]
        }

        let bucketStats = zip(buckets, currentTotals).map { bucket, totals in
            BucketStats(bucket: bucket, totals: totals)
        }

        return PeriodStats(
            range: range,
            comparisonRange: comparisonRange,
            comparisonMode: comparison,
            granularity: periodCalendar.granularity(for: range),
            buckets: bucketStats,
            totals: currentTotals.reduce(.zero, +),
            comparisonTotals: comparisonTotals,
            previousSeries: previousSeries,
            elapsedBucketCount: periodCalendar.elapsedBucketCount(in: buckets, at: now),
            isCurrentPeriod: periodCalendar.isCurrent(range, at: now),
            elapsedFraction: periodCalendar.elapsedFraction(of: range, at: now)
        )
    }
}
