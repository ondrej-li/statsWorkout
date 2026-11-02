import Foundation

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
        activities: [ActivitySample],
        steps: [StepSample],
        comparison: ComparisonMode = .previousPeriod,
        now: Date
    ) -> PeriodStats {
        let buckets = periodCalendar.buckets(for: range)
        let current = aggregate(range: range, buckets: buckets, activities: activities, steps: steps)

        let comparisonRange = periodCalendar.comparisonRange(for: range, mode: comparison)
        let previousBuckets = periodCalendar.buckets(for: comparisonRange)
        let previous = aggregate(
            range: comparisonRange,
            buckets: previousBuckets,
            activities: activities,
            steps: steps
        )

        let previousSeries = (0..<buckets.count).map { index in
            index < previous.totals.count ? previous.totals[index] : .zero
        }

        let elapsed = max(0, min(now.timeIntervalSince(range.start), range.duration))
        let comparisonCutoff = min(comparisonRange.start.addingTimeInterval(elapsed), comparisonRange.end)
        var comparisonTotals = MetricTotals.zero
        for (index, bucket) in previous.buckets.enumerated() where bucket.start < comparisonCutoff {
            comparisonTotals = comparisonTotals + previous.totals[index]
        }

        let bucketStats = zip(buckets, current.totals).map { bucket, totals in
            BucketStats(bucket: bucket, totals: totals)
        }

        return PeriodStats(
            range: range,
            comparisonRange: comparisonRange,
            comparisonMode: comparison,
            granularity: periodCalendar.granularity(for: range),
            buckets: bucketStats,
            totals: current.totals.reduce(.zero, +),
            comparisonTotals: comparisonTotals,
            previousSeries: previousSeries,
            elapsedBucketCount: periodCalendar.elapsedBucketCount(in: buckets, at: now),
            isCurrentPeriod: periodCalendar.isCurrent(range, at: now),
            elapsedFraction: periodCalendar.elapsedFraction(of: range, at: now)
        )
    }

    // MARK: - Private

    private func aggregate(
        range: PeriodRange,
        buckets: [Bucket],
        activities: [ActivitySample],
        steps: [StepSample]
    ) -> (totals: [MetricTotals], buckets: [Bucket]) {
        guard !buckets.isEmpty else { return ([], buckets) }

        var totals = Array(repeating: MetricTotals.zero, count: buckets.count)

        for activity in activities where activity.end > range.start && activity.start < range.end {
            let reference = max(activity.start, range.start)
            guard let index = periodCalendar.bucketIndex(containing: reference, in: buckets) else { continue }
            totals[index].add(activity)
        }

        for sample in steps where sample.count > 0 {
            let dayEnd = periodCalendar.calendar.date(byAdding: .day, value: 1, to: sample.day) ?? sample.day
            guard dayEnd > range.start, sample.day < range.end else { continue }
            let reference = max(sample.day, range.start)
            guard let index = periodCalendar.bucketIndex(containing: reference, in: buckets) else { continue }
            totals[index].steps += sample.count
        }

        return (totals, buckets)
    }
}
