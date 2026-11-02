import Foundation

/// Additive totals for every metric. Units are raw storage units
/// (metres, seconds) except steps and activity counts.
struct MetricTotals: Equatable, Sendable {
    var steps: Double = 0
    var distanceMeters: Double = 0
    var elevationGainMeters: Double = 0
    var exerciseDuration: TimeInterval = 0
    var activityCount: Int = 0

    static let zero = MetricTotals()

    var isEmpty: Bool {
        steps == 0 && distanceMeters == 0 && elevationGainMeters == 0 && exerciseDuration == 0 && activityCount == 0
    }

    func value(for metric: Metric) -> Double {
        switch metric {
        case .steps: return steps
        case .distance: return distanceMeters
        case .elevationGain: return elevationGainMeters
        case .exerciseDuration: return exerciseDuration
        case .activityCount: return Double(activityCount)
        }
    }

    mutating func add(_ activity: ActivitySample) {
        activityCount += 1
        exerciseDuration += activity.duration
        distanceMeters += activity.distanceMeters ?? 0
        elevationGainMeters += activity.elevationGainMeters ?? 0
    }

    static func + (lhs: MetricTotals, rhs: MetricTotals) -> MetricTotals {
        MetricTotals(
            steps: lhs.steps + rhs.steps,
            distanceMeters: lhs.distanceMeters + rhs.distanceMeters,
            elevationGainMeters: lhs.elevationGainMeters + rhs.elevationGainMeters,
            exerciseDuration: lhs.exerciseDuration + rhs.exerciseDuration,
            activityCount: lhs.activityCount + rhs.activityCount
        )
    }
}

struct BucketStats: Identifiable, Sendable, Equatable {
    let bucket: Bucket
    var totals: MetricTotals

    var id: Int { bucket.index }
}

/// Everything the dashboard needs for one period, computed in one pass.
struct PeriodStats: Sendable, Equatable {
    let range: PeriodRange
    let comparisonRange: PeriodRange
    let comparisonMode: ComparisonMode
    let granularity: BucketGranularity
    let buckets: [BucketStats]
    let totals: MetricTotals
    /// Previous-period totals limited to the same elapsed portion of the period.
    let comparisonTotals: MetricTotals
    /// Previous-period totals aligned bucket-by-bucket with `buckets`.
    let previousSeries: [MetricTotals]
    let elapsedBucketCount: Int
    let isCurrentPeriod: Bool
    let elapsedFraction: Double

    var isEmpty: Bool { totals.isEmpty }

    func value(of metric: Metric) -> Double {
        totals.value(for: metric)
    }

    func comparisonValue(of metric: Metric) -> Double {
        comparisonTotals.value(for: metric)
    }

    /// Relative change against the comparison window, `nil` when there is no baseline.
    func delta(of metric: Metric) -> Double? {
        let previous = comparisonValue(of: metric)
        guard previous > 0 else { return nil }
        return (value(of: metric) - previous) / previous
    }

    func average(of metric: Metric) -> Double {
        value(of: metric) / Double(max(elapsedBucketCount, 1))
    }

    func series(of metric: Metric) -> [Double] {
        buckets.map { $0.totals.value(for: metric) }
    }

    func cumulativeSeries(of metric: Metric) -> [Double] {
        var running = 0.0
        return buckets.map { bucket in
            running += bucket.totals.value(for: metric)
            return running
        }
    }

    func previousCumulativeSeries(of metric: Metric) -> [Double] {
        var running = 0.0
        return previousSeries.map { totals in
            running += totals.value(for: metric)
            return running
        }
    }
}
