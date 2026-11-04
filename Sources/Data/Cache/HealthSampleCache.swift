import Foundation

/// One day of totals, the unit the cache stores. Every dashboard period except
/// the day and 24-hour views can be assembled from these.
struct CachedDay: Codable, Sendable, Equatable {
    var day: Date
    var steps: Double = 0
    var distanceMeters: Double = 0
    var elevationMeters: Double = 0
    var workoutSteps: Double = 0
    var workoutDistanceMeters: Double = 0
}

/// Persisted Health samples, refreshed incrementally.
///
/// HealthKit stores a stream of samples; this keeps the daily roll-up so a
/// month, quarter or year view does not have to re-read years of history every
/// time the app opens. Recent days are re-read on each refresh, which also
/// picks up deletions and edits inside that window.
struct HealthSampleCache: Codable, Sendable, Equatable {
    static let currentVersion = 1
    /// Older days are dropped: the cache stays small and a year view is one query.
    static let retentionDays = 400

    var version: Int = HealthSampleCache.currentVersion
    /// Which data source produced this cache ("healthkit", "mock"). Switching
    /// sources invalidates it.
    var sourceKey: String = ""
    var lastSyncedAt: Date?
    /// When the whole requested range was last re-read, as opposed to the
    /// incremental tail. Used to schedule the occasional full refresh.
    var lastFullSyncAt: Date?
    var days: [CachedDay] = []
    var activities: [ActivitySample] = []

    // MARK: - Reading

    /// Assembles the samples the aggregator needs for `interval`.
    func samples(in interval: DateInterval) -> HealthSamples {
        let covered = days.filter { $0.day < interval.end && dayEnd($0.day) > interval.start }

        func series(_ value: (CachedDay) -> Double) -> [QuantitySample] {
            covered.compactMap { day in
                let amount = value(day)
                guard amount > 0 else { return nil }
                return QuantitySample(start: day.day, end: dayEnd(day.day), value: amount)
            }
        }

        return HealthSamples(
            activities: activities.filter { $0.start < interval.end && $0.end > interval.start },
            steps: covered.compactMap { day in
                day.steps > 0
                    ? StepSample(start: day.day, end: dayEnd(day.day), count: day.steps)
                    : nil
            },
            distance: series { $0.distanceMeters },
            elevation: series { $0.elevationMeters },
            workoutSteps: series { $0.workoutSteps },
            workoutDistance: series { $0.workoutDistanceMeters }
        )
    }

    func day(_ date: Date, in calendar: Calendar) -> CachedDay? {
        let start = calendar.startOfDay(for: date)
        return days.first { $0.day == start }
    }

    // MARK: - Writing

    /// Replaces everything the refresh covered, so edited and deleted samples
    /// inside that window are picked up as well as new ones.
    mutating func merge(_ fresh: [CachedDay], activities freshActivities: [ActivitySample], covering window: DateInterval) {
        // Deliberately half-open: `DateInterval.contains` also matches its end
        // date, which would drop the first day after the refreshed window.
        func covers(_ date: Date) -> Bool {
            date >= window.start && date < window.end
        }

        let keptDays = days.filter { !covers($0.day) }
        days = (keptDays + fresh).sorted { $0.day < $1.day }

        let keptActivities = activities.filter { !covers($0.start) }
        let merged = keptActivities + freshActivities
        var seen = Set<UUID>()
        activities = merged
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.start > $1.start }
    }

    mutating func prune(olderThan cutoff: Date) {
        days.removeAll { $0.day < cutoff }
        activities.removeAll { $0.start < cutoff }
    }

    private func dayEnd(_ day: Date) -> Date {
        day.addingTimeInterval(86_400)
    }
}
