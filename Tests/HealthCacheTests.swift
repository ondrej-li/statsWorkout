import Foundation
import Testing
@testable import StatsWorkout

/// Health data source that records what was asked for and returns fixed values.
actor RecordingHealthDataSource: HealthDataProviding {
    struct Request: Equatable, Sendable {
        let start: Date
        let end: Date
        let granularity: StepGranularity
    }

    nonisolated let isAvailable = true
    private(set) var requests: [Request] = []
    private let stepsPerDay: Double
    private let calendar: Calendar

    init(stepsPerDay: Double = 8_000, calendar: Calendar = TestSupport.calendar()) {
        self.stepsPerDay = stepsPerDay
        self.calendar = calendar
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationStatus { .unnecessary }
    func requestAuthorization() async throws {}

    func activities(in interval: DateInterval) async throws -> [ActivitySample] {
        requests.append(Request(start: interval.start, end: interval.end, granularity: .day))
        return []
    }

    func stepSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [StepSample] {
        requests.append(Request(start: interval.start, end: interval.end, granularity: granularity))
        var samples: [StepSample] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            let end = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
            samples.append(StepSample(start: day, end: end, count: stepsPerDay))
            day = end
        }
        return samples
    }

    func distanceSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        requests.append(Request(start: interval.start, end: interval.end, granularity: granularity))
        return []
    }

    func elevationSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        requests.append(Request(start: interval.start, end: interval.end, granularity: granularity))
        return []
    }

    func workoutQuantitySamples(
        in interval: DateInterval,
        kind: ContinuousQuantity,
        within windows: [DateInterval],
        granularity: StepGranularity
    ) async throws -> [QuantitySample] {
        []
    }

    func workoutDetail(for activity: ActivitySample) async throws -> WorkoutDetail {
        WorkoutDetail()
    }

    func reset() { requests.removeAll() }

    /// Windows requested at day granularity.
    func dayWindows() -> [Request] {
        requests.filter { $0.granularity == .day }
    }

    /// Windows requested at hour granularity.
    func hourWindows() -> [Request] {
        requests.filter { $0.granularity == .hour }
    }
}

final class InMemoryHealthCacheStore: HealthCacheStoring, @unchecked Sendable {
    private let state = LockedCacheState()

    func load() async -> HealthSampleCache? { state.read() }
    func save(_ cache: HealthSampleCache) async { state.write(cache) }
    func clear() async { state.write(nil) }
}

/// Small mutex wrapper: `NSLock` cannot be called from async contexts.
private final class LockedCacheState: @unchecked Sendable {
    private let lock = NSLock()
    private var value: HealthSampleCache?

    func read() -> HealthSampleCache? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func write(_ cache: HealthSampleCache?) {
        lock.lock()
        value = cache
        lock.unlock()
    }
}

@Suite("Health cache")
struct HealthSampleCacheTests {
    private let calendar = TestSupport.calendar()

    private func day(_ value: Int) -> Date {
        TestSupport.date(calendar, 2026, 11, value)
    }

    @Test("Merging replaces only the refreshed window")
    func mergeReplacesWindow() {
        var cache = HealthSampleCache()
        cache.days = [
            CachedDay(day: day(1), steps: 1_000),
            CachedDay(day: day(2), steps: 2_000),
            CachedDay(day: day(3), steps: 3_000)
        ]

        // Everything the refresh covered is replaced, so the window is one day.
        let window = DateInterval(start: day(2), end: day(3))
        cache.merge([CachedDay(day: day(2), steps: 9_000)], activities: [], covering: window)

        #expect(cache.days.map(\.day) == [day(1), day(2), day(3)])
        #expect(cache.days.map(\.steps) == [1_000, 9_000, 3_000])
    }

    @Test("Merging keeps workouts outside the window and dedupes the rest")
    func mergeActivities() {
        let keep = ActivitySample(kind: .running, start: day(1), end: day(1).addingTimeInterval(3_600))
        let replaced = ActivitySample(kind: .walking, start: day(5), end: day(5).addingTimeInterval(3_600))
        let fresh = ActivitySample(kind: .cycling, start: day(5).addingTimeInterval(600), end: day(5).addingTimeInterval(4_200))

        var cache = HealthSampleCache()
        cache.activities = [keep, replaced]
        cache.merge([], activities: [fresh], covering: DateInterval(start: day(5), end: day(6)))

        let days = cache.activities.map { calendar.component(.day, from: $0.start) }
        #expect(days == [5, 1])
        #expect(cache.activities.first?.kind == .cycling)
    }

    @Test("Pruning drops days and workouts older than the cutoff")
    func pruning() {
        var cache = HealthSampleCache()
        cache.days = [CachedDay(day: day(1), steps: 10), CachedDay(day: day(20), steps: 20)]
        cache.activities = [ActivitySample(kind: .running, start: day(1), end: day(1).addingTimeInterval(60)),
                            ActivitySample(kind: .walking, start: day(20), end: day(20).addingTimeInterval(60))]

        cache.prune(olderThan: day(10))

        #expect(cache.days.map(\.steps) == [20])
        #expect(cache.activities.count == 1)
    }

    @Test("Samples are rebuilt from the cached days")
    func samplesFromCache() {
        var cache = HealthSampleCache(sourceKey: "healthkit")
        cache.days = [
            CachedDay(day: day(1), steps: 5_000, distanceMeters: 3_000, elevationMeters: 40,
                      workoutSteps: 2_000, workoutDistanceMeters: 1_500),
            CachedDay(day: day(2), steps: 6_000, distanceMeters: 4_000, elevationMeters: 20)
        ]

        let samples = cache.samples(in: DateInterval(start: day(1), end: day(3)))

        #expect(samples.steps.map(\.count) == [5_000, 6_000])
        #expect(samples.distance.map(\.value) == [3_000, 4_000])
        #expect(samples.elevation.map(\.value) == [40, 20])
        #expect(samples.workoutSteps.map(\.value) == [2_000])
        #expect(samples.workoutDistance.map(\.value) == [1_500])
    }

    @Test("Samples are clipped to the requested interval")
    func samplesClipped() {
        var cache = HealthSampleCache()
        cache.days = [CachedDay(day: day(1), steps: 5_000), CachedDay(day: day(5), steps: 7_000)]

        let samples = cache.samples(in: DateInterval(start: day(3), end: day(6)))
        #expect(samples.steps.map(\.count) == [7_000])
    }
}

@Suite("Health sync")
struct HealthSyncCoordinatorTests {
    private let calendar = TestSupport.calendar()
    private var now: Date { TestSupport.date(calendar, 2026, 11, 10, 18) }
    private var window: DateInterval {
        DateInterval(start: TestSupport.date(calendar, 2026, 10, 1), end: now)
    }

    private func makeCoordinator(_ store: InMemoryHealthCacheStore) -> HealthSyncCoordinator {
        HealthSyncCoordinator(store: store, calendar: calendar)
    }

    private func source() -> RecordingHealthDataSource {
        RecordingHealthDataSource(calendar: calendar)
    }

    @Test("First load reads the whole window and caches it")
    func firstLoad() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        let samples = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: now
        )

        #expect(!samples.steps.isEmpty)
        #expect(await source.dayWindows().count == 4)  // activities, steps, distance, elevation
        let cache = await store.load()
        #expect(cache?.days.count == 41)
        #expect(cache?.lastFullSyncAt == now)
    }

    @Test("A second load inside the refresh interval does not touch HealthKit")
    func cachedLoad() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: now
        )
        await source.reset()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test",
            now: now.addingTimeInterval(10)
        )

        #expect(await source.dayWindows().isEmpty)
    }

    @Test("A later load only re-reads the tail of the window")
    func incrementalRefresh() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: now
        )
        await source.reset()

        let later = now.addingTimeInterval(3_600)
        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: later
        )

        let stepsWindow = await source.dayWindows()
        #expect(!stepsWindow.isEmpty)
        // Two days of overlap, never the whole month again.
        #expect(stepsWindow.allSatisfy { $0.start >= TestSupport.date(calendar, 2026, 11, 7) })
    }

    @Test("A forced load re-reads everything")
    func forcedRefresh() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: now
        )
        await source.reset()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test",
            now: now.addingTimeInterval(5), force: true
        )

        #expect(await source.dayWindows().first?.start == window.start)
    }

    @Test("Hourly views bypass the cache")
    func hourlyBypassesCache() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()
        let dayWindow = DateInterval(
            start: TestSupport.date(calendar, 2026, 11, 9),
            end: TestSupport.date(calendar, 2026, 11, 10)
        )

        _ = try await coordinator.loadSamples(
            for: dayWindow, granularity: .hour, source: source, sourceKey: "test", now: now
        )

        let hourlyWindows = await source.hourWindows()
        #expect(!hourlyWindows.isEmpty)
        #expect(await store.load() == nil)
    }

    @Test("Switching data source discards the cache")
    func sourceSwitchInvalidates() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "healthkit", now: now
        )
        let mockSamples = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "mock", now: now
        )

        #expect(!mockSamples.steps.isEmpty)
        #expect(await store.load()?.sourceKey == "mock")
    }

    @Test("The cache reports what it holds")
    func cacheInfo() async throws {
        let store = InMemoryHealthCacheStore()
        let coordinator = makeCoordinator(store)
        let source = source()

        _ = try await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "test", now: now
        )
        let info = await coordinator.cacheInfo(sourceKey: "test")

        #expect(info.dayCount == 41)
        #expect(info.lastSyncedAt == now)
    }
}
