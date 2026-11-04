import Foundation

/// Loads dashboard samples through the cache, refreshing only what changed.
///
/// Long ranges are expensive to read from HealthKit, so their daily totals are
/// cached and only the days since the last sync are re-read (plus a short
/// overlap, which also catches edits and deletions). Day and 24-hour views read
/// hourly data straight from HealthKit — the window is two days at most.
actor HealthSyncCoordinator {
    /// Days re-read on every refresh, to absorb late-arriving samples.
    static let overlapDays = 2
    /// A full re-read is forced at most this often, in case something outside
    /// the overlap window was deleted in the Health app.
    static let fullRefreshInterval: TimeInterval = 24 * 60 * 60
    /// Repeated loads inside this window reuse the cache untouched.
    static let minimumRefreshInterval: TimeInterval = 60

    struct Configuration: Sendable {
        var overlapDays = HealthSyncCoordinator.overlapDays
        var fullRefreshInterval = HealthSyncCoordinator.fullRefreshInterval
        var minimumRefreshInterval = HealthSyncCoordinator.minimumRefreshInterval
        var retentionDays = HealthSampleCache.retentionDays
    }

    private let store: any HealthCacheStoring
    private let calendar: Calendar
    private let configuration: Configuration
    private var cache: HealthSampleCache?

    init(
        store: any HealthCacheStoring,
        calendar: Calendar = .current,
        configuration: Configuration = Configuration()
    ) {
        self.store = store
        self.calendar = calendar
        self.configuration = configuration
    }

    // MARK: - Loading

    func loadSamples(
        for window: DateInterval,
        granularity: StepGranularity,
        source: any HealthDataProviding,
        sourceKey: String,
        now: Date,
        force: Bool = false
    ) async throws -> HealthSamples {
        guard window.duration > 0 else { return HealthSamples() }

        // Hourly views are two days at most; reading them live is cheaper than
        // keeping an hourly cache.
        if granularity == .hour {
            return try await fetchSamples(source: source, window: window, granularity: .hour)
        }

        var cache = await currentCache(sourceKey: sourceKey)

        let plan = refreshPlan(for: window, cache: cache, now: now, force: force)
        switch plan {
        case .none:
            break
        case .partial(let refresh), .full(let refresh):
            let fresh = try await fetchDays(source: source, window: refresh)
            cache.merge(fresh.days, activities: fresh.activities, covering: refresh)
            cache.lastSyncedAt = now
            if case .full = plan {
                cache.lastFullSyncAt = now
            }
            cache.prune(olderThan: now.addingTimeInterval(-Double(configuration.retentionDays) * 86_400))
            self.cache = cache
            await store.save(cache)
        }

        return cache.samples(in: window)
    }

    struct CacheInfo: Sendable, Equatable {
        var dayCount: Int
        var activityCount: Int
        var lastSyncedAt: Date?
    }

    /// What is currently held on disk, for the Settings screen.
    func cacheInfo(sourceKey: String) async -> CacheInfo {
        let cache = await currentCache(sourceKey: sourceKey)
        return CacheInfo(
            dayCount: cache.days.count,
            activityCount: cache.activities.count,
            lastSyncedAt: cache.lastSyncedAt
        )
    }

    /// Drops the cache, e.g. after a Health update or a data-source change.
    func invalidate() async {
        cache = nil
        await store.clear()
    }

    // MARK: - Refresh planning

    private enum RefreshPlan {
        case none
        case partial(DateInterval)
        case full(DateInterval)
    }

    private func refreshPlan(
        for window: DateInterval,
        cache: HealthSampleCache,
        now: Date,
        force: Bool
    ) -> RefreshPlan {
        if force || cache.days.isEmpty || cache.lastFullSyncAt == nil {
            return .full(window)
        }
        if let lastFullSyncAt = cache.lastFullSyncAt,
           now.timeIntervalSince(lastFullSyncAt) >= configuration.fullRefreshInterval {
            return .full(window)
        }
        guard let lastSyncedAt = cache.lastSyncedAt else { return .full(window) }
        guard now.timeIntervalSince(lastSyncedAt) >= configuration.minimumRefreshInterval else {
            return .none
        }

        // Re-read from a little before the last sync, never earlier than the
        // requested range.
        let overlapStart = calendar.startOfDay(for: lastSyncedAt)
            .addingTimeInterval(-Double(configuration.overlapDays) * 86_400)
        let start = max(window.start, min(overlapStart, window.end))
        guard start < window.end else { return .none }
        return .partial(DateInterval(start: start, end: window.end))
    }

    // MARK: - Fetching

    /// Everything the aggregator needs for `window`, straight from HealthKit.
    private func fetchSamples(
        source: any HealthDataProviding,
        window: DateInterval,
        granularity: StepGranularity
    ) async throws -> HealthSamples {
        async let activitiesTask = source.activities(in: window)
        async let stepsTask = source.stepSamples(in: window, granularity: granularity)
        async let distanceTask = source.distanceSamples(in: window, granularity: granularity)
        async let elevationTask = source.elevationSamples(in: window, granularity: granularity)

        let (activities, steps, distance, elevation) = try await (
            activitiesTask, stepsTask, distanceTask, elevationTask
        )

        let windows = activities.map { DateInterval(start: $0.start, end: $0.end) }
        async let workoutStepsTask = source.workoutQuantitySamples(
            in: window, kind: .steps, within: windows, granularity: granularity
        )
        async let workoutDistanceTask = source.workoutQuantitySamples(
            in: window, kind: .distance, within: windows, granularity: granularity
        )
        let (workoutSteps, workoutDistance) = try await (workoutStepsTask, workoutDistanceTask)

        return HealthSamples(
            activities: activities,
            steps: steps,
            distance: distance,
            elevation: elevation,
            workoutSteps: workoutSteps,
            workoutDistance: workoutDistance
        )
    }

    /// The same data rolled up per day, which is what the cache stores.
    private func fetchDays(
        source: any HealthDataProviding,
        window: DateInterval
    ) async throws -> (days: [CachedDay], activities: [ActivitySample]) {
        let samples = try await fetchSamples(source: source, window: window, granularity: .day)

        var byDay: [Date: CachedDay] = [:]
        func entry(_ date: Date) -> CachedDay {
            let day = calendar.startOfDay(for: date)
            return byDay[day] ?? CachedDay(day: day)
        }
        func add(_ samples: [QuantitySample], _ keyPath: WritableKeyPath<CachedDay, Double>) {
            for sample in samples where sample.value > 0 {
                var day = entry(sample.start)
                day[keyPath: keyPath] += sample.value
                byDay[day.day] = day
            }
        }

        for sample in samples.steps where sample.count > 0 {
            var day = entry(sample.start)
            day.steps += sample.count
            byDay[day.day] = day
        }
        add(samples.distance, \.distanceMeters)
        add(samples.elevation, \.elevationMeters)
        add(samples.workoutSteps, \.workoutSteps)
        add(samples.workoutDistance, \.workoutDistanceMeters)

        return (byDay.values.sorted { $0.day < $1.day }, samples.activities)
    }

    // MARK: - Cache access

    private func currentCache(sourceKey: String) async -> HealthSampleCache {
        if let cache {
            if cache.sourceKey == sourceKey { return cache }
            await store.clear()
        }

        var loaded = await store.load() ?? HealthSampleCache()
        if loaded.sourceKey != sourceKey {
            loaded = HealthSampleCache(sourceKey: sourceKey)
        }
        cache = loaded
        return loaded
    }
}
