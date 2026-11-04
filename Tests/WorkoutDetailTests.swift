import Foundation
import Testing
@testable import StatsWorkout

@Suite("Workout naming")
struct WorkoutNamingTests {
    private let calendar = TestSupport.calendar()
    private var naming: WorkoutNaming { WorkoutNaming(calendar: calendar) }

    private func activity(_ kind: ActivityKind, hour: Int) -> ActivitySample {
        let start = TestSupport.date(calendar, 2026, 11, 3, hour)
        return ActivitySample(kind: kind, start: start, end: start.addingTimeInterval(3_600))
    }

    @Test("Time of day boundaries")
    func timeOfDay() {
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 4, 59), calendar: calendar) == .night)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 5, 0), calendar: calendar) == .morning)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 11, 59), calendar: calendar) == .morning)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 12, 0), calendar: calendar) == .afternoon)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 16, 59), calendar: calendar) == .afternoon)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 17, 0), calendar: calendar) == .evening)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 21, 59), calendar: calendar) == .evening)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 22, 0), calendar: calendar) == .night)
    }

    @Test("Titles read the way a person would describe the workout")
    func titles() {
        #expect(naming.title(for: activity(.walking, hour: 7), place: "Brtnice")
            == "Your morning walk around Brtnice")
        #expect(naming.title(for: activity(.running, hour: 23), place: "Okříšky")
            == "Your night run around Okříšky")
        #expect(naming.title(for: activity(.cycling, hour: 15), place: "Třebíč")
            == "Your afternoon ride around Třebíč")
    }

    @Test("A workout without a place still gets a title")
    func withoutPlace() {
        #expect(naming.title(for: activity(.strength, hour: 18), place: nil)
            == "Your evening strength workout")
        #expect(naming.title(for: activity(.yoga, hour: 9), place: "   ")
            == "Your morning yoga session")
    }

    @Test("Placemark names are reduced to the settlement")
    func placeCleaning() {
        #expect(WorkoutNaming.cleanedPlace("Brtnice, Czechia") == "Brtnice")
        #expect(WorkoutNaming.cleanedPlace("  brtnice ") == "Brtnice")
        #expect(WorkoutNaming.cleanedPlace("") == nil)
        #expect(WorkoutNaming.cleanedPlace(nil) == nil)
    }

    @Test("Short title for lists")
    func shortTitles() {
        #expect(naming.shortTitle(for: activity(.hiking, hour: 6), place: "Jihlava")
            == "Morning hike around Jihlava")
    }
}

@Suite("Route geometry")
struct RouteGeometryTests {
    private func point(_ latitude: Double, _ longitude: Double, minutes: Double? = nil) -> RoutePoint {
        RoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: nil,
            time: minutes.map { TestSupport.date(TestSupport.calendar(), 2026, 11, 3).addingTimeInterval($0 * 60) }
        )
    }

    @Test("One degree of latitude is about 111 km")
    func distance() {
        let metres = RouteGeometry.distance(from: point(49, 15), to: point(50, 15))
        #expect(metres > 110_000 && metres < 112_000)
    }

    @Test("Centroid and bounds cover the route")
    func centroidAndBounds() {
        let route = [point(49.30, 15.60), point(49.32, 15.64), point(49.28, 15.62)]
        let centre = try? #require(RouteGeometry.centroid(of: route))
        #expect(abs((centre?.latitude ?? 0) - 49.30) < 0.0001)
        #expect(abs((centre?.longitude ?? 0) - 15.62) < 0.0001)

        let bounds = RouteGeometry.bounds(of: route)
        #expect(bounds?.minLatitude == 49.28)
        #expect(bounds?.maxLongitude == 15.64)
        if let span = bounds?.span() {
            #expect(span.latitude > 0.04)
        } else {
            Issue.record("Expected bounds for a non-empty route")
        }
    }

    /// 4 km straight north over 20 minutes, sampled every 100 m.
    private func straightRoute(kilometres: Double, minutes: Double) -> [RoutePoint] {
        let steps = Int(kilometres * 10)
        let metresPerStep = 100.0
        let degreesPerStep = metresPerStep / 111_000
        return (0...steps).map { index in
            let progress = Double(index) / Double(steps)
            return RoutePoint(
                latitude: 49.30 + degreesPerStep * Double(index),
                longitude: 15.6,
                altitude: 400,
                time: TestSupport.date(TestSupport.calendar(), 2026, 11, 3)
                    .addingTimeInterval(minutes * 60 * progress)
            )
        }
    }

    @Test("Splits are even for an even route")
    func evenSplits() {
        let splits = RouteGeometry.splits(of: straightRoute(kilometres: 4, minutes: 20), splitLength: 1_000)

        #expect(splits.count == 4)
        #expect(splits.allSatisfy { abs($0.duration - 300) < 3 })
        #expect(splits.map(\.index) == [1, 2, 3, 4])
    }

    @Test("A trailing partial split keeps its real pace")
    func partialSplit() {
        let splits = RouteGeometry.splits(of: straightRoute(kilometres: 2.5, minutes: 15), splitLength: 1_000)

        #expect(splits.count == 3)
        #expect(abs((splits.last?.distance ?? 0) - 0.5) < 0.02)
        #expect(abs((splits.last?.duration ?? 0) - 180) < 3)
        #expect(abs((splits.last?.pace ?? 0) - 360) < 8)
    }

    @Test("Splits follow the distance HealthKit recorded, not the raw trace")
    func calibratedSplits() {
        // A 4.0 km workout whose GPS trace runs 10% long.
        let route = straightRoute(kilometres: 4.4, minutes: 20)
        let splits = RouteGeometry.splits(of: route, splitLength: 1_000, totalDistance: 4_000)

        #expect(splits.count == 4)
        #expect(abs(splits.reduce(0) { $0 + $1.distance } - 4.0) < 0.2)
    }

    @Test("Routes shorter than a split produce nothing")
    func shortRoute() {
        #expect(RouteGeometry.splits(of: straightRoute(kilometres: 0.05, minutes: 1), splitLength: 1_000).isEmpty)
    }
}

@Suite("Workout naming in the app")
@MainActor
struct WorkoutNamingIntegrationTests {
    private let calendar = TestSupport.calendar()

    private func makeEnvironment(store: InMemoryHealthCacheStore) -> AppEnvironment {
        let settings = AppSettings(persists: false)
        settings.useMockData = true
        let source = MockHealthDataSource(calendar: calendar, seed: 42)
        return AppEnvironment(
            settings: settings,
            healthKit: source,
            mock: source,
            calendar: calendar,
            cacheStore: store,
            mockPlaces: MockPlaceResolver()
        )
    }

    private func sampleActivity() -> ActivitySample {
        let interval = DateInterval(
            start: TestSupport.date(calendar, 2026, 10, 1),
            end: TestSupport.date(calendar, 2026, 10, 20)
        )
        return MockHealthData.activities(in: interval, calendar: calendar, seed: 42, now: interval.end)
            .first { $0.kind.isDistanceBased }!
    }

    @Test("A row starts without a place and gains one once resolved")
    func resolvesPlace() async {
        let store = InMemoryHealthCacheStore()
        let environment = makeEnvironment(store: store)
        let activity = sampleActivity()

        let initial = environment.workoutTitle(for: activity)
        #expect(!initial.contains(" around "))

        await environment.resolveWorkoutPlaces(for: [activity])
        let resolved = environment.workoutTitle(for: activity)

        #expect(resolved.hasPrefix("Your "))
        #expect(resolved.contains(" around "))
        #expect(MockTown.all.contains { resolved.hasSuffix($0.name) })
    }

    @Test("Resolved names are cached and survive the next launch")
    func cachesNames() async {
        let store = InMemoryHealthCacheStore()
        let environment = makeEnvironment(store: store)
        let activity = sampleActivity()
        await environment.resolveWorkoutPlaces(for: [activity])
        let title = environment.workoutTitle(for: activity)

        // A fresh environment reads the place back from the cache.
        let relaunched = makeEnvironment(store: store)
        await relaunched.resolveWorkoutPlaces(for: [activity])

        #expect(relaunched.workoutTitle(for: activity) == title)
    }

    @Test("Real data is read from HealthKit, demo data from the generator")
    func dataSourceSelection() {
        let settings = AppSettings(persists: false)
        let store = InMemoryHealthCacheStore()
        let healthKit = MockHealthDataSource(calendar: calendar, seed: 1)
        let mock = MockHealthDataSource(calendar: calendar, seed: 2)
        let environment = AppEnvironment(
            settings: settings,
            healthKit: healthKit,
            mock: mock,
            calendar: calendar,
            cacheStore: store,
            mockPlaces: MockPlaceResolver()
        )

        // A workout route can only be generated while demo data is switched on.
        settings.useMockData = true
        #expect(environment.dataSourceKey == "mock")

        settings.useMockData = false
        #expect(environment.dataSourceKey == "healthkit")
    }

    @Test("A workout is always resolved against the source that made it")
    func perActivitySource() async {
        let settings = AppSettings(persists: false)
        // The "HealthKit" side is a source with no routes at all, so a route in
        // the result can only have come from the demo generator.
        let environment = AppEnvironment(
            settings: settings,
            healthKit: RecordingHealthDataSource(calendar: calendar),
            mock: MockHealthDataSource(calendar: calendar, seed: 2),
            calendar: calendar,
            cacheStore: InMemoryHealthCacheStore(),
            mockPlaces: MockPlaceResolver()
        )

        let recorded = ActivitySample(
            kind: .walking,
            start: TestSupport.date(calendar, 2026, 11, 3, 8),
            end: TestSupport.date(calendar, 2026, 11, 3, 9),
            healthKitUUID: UUID()
        )
        let generated = ActivitySample(
            kind: .walking,
            start: TestSupport.date(calendar, 2026, 11, 3, 8),
            end: TestSupport.date(calendar, 2026, 11, 3, 9)
        )

        // Demo mode must never reach a recorded workout.
        settings.useMockData = true

        let recordedSource = environment.dataSource(for: recorded)
        let generatedSource = environment.dataSource(for: generated)

        // The mock returns a generated route; HealthKit has none for a fake id,
        // which is enough to tell the two apart here.
        let recordedDetail = try? await recordedSource.workoutDetail(for: recorded)
        let generatedDetail = try? await generatedSource.workoutDetail(for: generated)

        #expect(recordedDetail?.route.isEmpty == true)
        #expect(generatedDetail?.route.isEmpty == false)
    }

    @Test("A recorded workout never gets a generated route")
    func recordedWorkoutHasNoFakeRoute() async {
        let settings = AppSettings(persists: false)
        let environment = AppEnvironment(
            settings: settings,
            healthKit: RecordingHealthDataSource(calendar: calendar),
            mock: MockHealthDataSource(calendar: calendar, seed: 2),
            calendar: calendar,
            cacheStore: InMemoryHealthCacheStore(),
            mockPlaces: MockPlaceResolver()
        )
        settings.useMockData = true

        // A genuine workout: HealthKit identity, no route recorded for it.
        let recorded = ActivitySample(
            kind: .walking,
            start: TestSupport.date(calendar, 2026, 11, 3, 8),
            end: TestSupport.date(calendar, 2026, 11, 3, 9, 10),
            distanceMeters: 4_130,
            healthKitUUID: UUID()
        )

        let model = ActivityDetailViewModel(activity: recorded, environment: environment)
        await model.load()

        #expect(model.detail.route.isEmpty)
        #expect(model.provenance == .notRecorded)
        #expect(model.splits.isEmpty)
        #expect(model.title.contains(" around ") == false)
    }

    @Test("A demo workout is labelled as such")
    func demoWorkoutIsLabelled() async {
        let settings = AppSettings(persists: false)
        settings.useMockData = true
        let environment = AppEnvironment(
            settings: settings,
            healthKit: RecordingHealthDataSource(calendar: calendar),
            mock: MockHealthDataSource(calendar: calendar, seed: 2),
            calendar: calendar,
            cacheStore: InMemoryHealthCacheStore(),
            mockPlaces: MockPlaceResolver()
        )

        let generated = ActivitySample(
            kind: .walking,
            start: TestSupport.date(calendar, 2026, 11, 3, 8),
            end: TestSupport.date(calendar, 2026, 11, 3, 9),
            distanceMeters: 4_000
        )

        let model = ActivityDetailViewModel(activity: generated, environment: environment)
        await model.load()

        #expect(model.isDemo)
        #expect(model.provenance == .demo)
        #expect(model.detail.route.isEmpty == false)
    }

    @Test("Places for workouts that left the cache are pruned")
    func prunesPlaces() async {
        let store = InMemoryHealthCacheStore()
        let coordinator = HealthSyncCoordinator(store: store, calendar: calendar)
        let window = DateInterval(
            start: TestSupport.date(calendar, 2026, 10, 1),
            end: TestSupport.date(calendar, 2026, 10, 20)
        )
        let source = MockHealthDataSource(calendar: calendar, seed: 42)

        _ = try? await coordinator.loadSamples(
            for: window, granularity: .day, source: source, sourceKey: "mock", now: window.end
        )
        let activity = sampleActivity()
        await coordinator.setPlaceName("Brtnice", for: activity.stableID, sourceKey: "mock")

        #expect(await coordinator.placeNames(sourceKey: "mock")[activity.stableID] == "Brtnice")

        await coordinator.invalidate()
        #expect(await coordinator.placeNames(sourceKey: "mock").isEmpty)
    }
}
