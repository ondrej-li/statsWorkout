import Foundation
import HealthKit

/// Read-only HealthKit implementation of `HealthDataProviding`.
///
/// All queries are scoped to the requested interval so the dashboard only pays
/// for the data it draws.
struct HealthKitDataSource: HealthDataProviding {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private static let distanceQuantityTypes: [HKQuantityType] = [
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming)
    ]

    static var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKObjectType.workoutType()
        ]
    }

    func authorizationRequestStatus() async throws -> HealthAuthorizationStatus {
        guard isAvailable else { throw HealthDataError.unavailable }

        let status = try await store.statusForAuthorizationRequest(toShare: [], read: Self.readTypes)
        switch status {
        case .shouldRequest: return .shouldRequest
        case .unnecessary: return .unnecessary
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthDataError.unavailable }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func activities(in interval: DateInterval) async throws -> [ActivitySample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\HKWorkout.startDate, order: .forward)]
        )

        do {
            let workouts = try await descriptor.result(for: store)
            return workouts.map(WorkoutMapper.activity(from:))
        } catch {
            throw Self.map(error)
        }
    }

    func stepSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [StepSample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        do {
            let collection = try await statisticsCollection(
                for: HKQuantityType(.stepCount),
                in: interval,
                granularity: granularity
            )
            var samples: [StepSample] = []
            collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                guard count > 0 else { return }
                samples.append(
                    StepSample(start: statistics.startDate, end: statistics.endDate, count: count)
                )
            }
            return samples
        } catch {
            throw Self.map(error)
        }
    }

    func distanceSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        do {
            var buckets: [Date: (end: Date, value: Double)] = [:]
            for type in Self.distanceQuantityTypes {
                let collection = try await statisticsCollection(for: type, in: interval, granularity: granularity)
                collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                    guard let meters = statistics.sumQuantity()?.doubleValue(for: .meter()), meters > 0 else { return }
                    let existing = buckets[statistics.startDate]
                    buckets[statistics.startDate] = (statistics.endDate, (existing?.value ?? 0) + meters)
                }
            }
            return buckets
                .map { QuantitySample(start: $0.key, end: $0.value.end, value: $0.value.value) }
                .sorted { $0.start < $1.start }
        } catch {
            throw Self.map(error)
        }
    }

    func elevationSamples(in interval: DateInterval, granularity: StepGranularity) async throws -> [QuantitySample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        do {
            let collection = try await statisticsCollection(
                for: HKQuantityType(.flightsClimbed),
                in: interval,
                granularity: granularity
            )
            var samples: [QuantitySample] = []
            collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                let flights = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                guard flights > 0 else { return }
                samples.append(
                    QuantitySample(
                        start: statistics.startDate,
                        end: statistics.endDate,
                        value: flights * WorkoutMapper.metersPerFlight
                    )
                )
            }
            return samples
        } catch {
            throw Self.map(error)
        }
    }

    private func statisticsCollection(
        for type: HKQuantityType,
        in interval: DateInterval,
        granularity: StepGranularity,
        predicate samplePredicate: NSPredicate? = nil
    ) async throws -> HKStatisticsCollection {
        let calendar = Calendar.current
        let predicate = samplePredicate ?? HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )

        let components: DateComponents
        let anchor: Date
        switch granularity {
        case .hour:
            components = DateComponents(hour: 1)
            anchor = calendar.dateInterval(of: .hour, for: interval.start)?.start ?? interval.start
        case .day:
            components = DateComponents(day: 1)
            anchor = calendar.startOfDay(for: interval.start)
        }

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: components
        )
        return try await descriptor.result(for: store)
    }

    func workoutQuantitySamples(
        in interval: DateInterval,
        kind: ContinuousQuantity,
        within windows: [DateInterval],
        granularity: StepGranularity
    ) async throws -> [QuantitySample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        let merged = Self.merge(windows, clippedTo: interval)
        guard !merged.isEmpty else { return [] }

        let types: [HKQuantityType]
        let unit: HKUnit
        switch kind {
        case .steps:
            types = [HKQuantityType(.stepCount)]
            unit = .count()
        case .distance:
            types = Self.distanceQuantityTypes
            unit = .meter()
        }

        do {
            var totals: [Date: (end: Date, value: Double)] = [:]

            func accumulate(_ predicate: NSPredicate) async throws {
                for type in types {
                    let collection = try await statisticsCollection(
                        for: type,
                        in: interval,
                        granularity: granularity,
                        predicate: predicate
                    )
                    collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                        guard let sum = statistics.sumQuantity()?.doubleValue(for: unit), sum > 0 else { return }
                        let existing = totals[statistics.startDate]
                        totals[statistics.startDate] = (statistics.endDate, (existing?.value ?? 0) + sum)
                    }
                }
            }

            func windowPredicate(_ window: DateInterval) -> NSPredicate {
                HKQuery.predicateForSamples(
                    withStart: window.start,
                    end: window.end,
                    options: [.strictStartDate]
                )
            }

            // HealthKit expands each subpredicate, so long workout lists are split
            // into chunks instead of one giant compound predicate.
            for chunk in merged.chunked(maxSize: 60) {
                do {
                    try await accumulate(
                        NSCompoundPredicate(orPredicateWithSubpredicates: chunk.map(windowPredicate))
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // A compound predicate is rejected in some configurations;
                    // query the windows one by one instead.
                    for window in chunk {
                        try await accumulate(windowPredicate(window))
                    }
                }
            }

            return totals
                .map { QuantitySample(start: $0.key, end: $0.value.end, value: $0.value.value) }
                .sorted { $0.start < $1.start }
        } catch {
            throw Self.map(error)
        }
    }

    /// Clips windows to the query interval and merges overlapping ones.
    private static func merge(_ windows: [DateInterval], clippedTo interval: DateInterval) -> [DateInterval] {
        let clipped = windows.compactMap { window -> DateInterval? in
            let start = max(window.start, interval.start)
            let end = min(window.end, interval.end)
            return end > start ? DateInterval(start: start, end: end) : nil
        }.sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for window in clipped {
            if let last = merged.last, window.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, window.end))
            } else {
                merged.append(window)
            }
        }
        return merged
    }

    func workoutDetail(for activity: ActivitySample) async throws -> WorkoutDetail {
        guard isAvailable else { throw HealthDataError.unavailable }

        let window = DateInterval(start: activity.start, end: activity.end)

        // Each helper builds its own predicate: NSPredicate is not Sendable, so
        // it cannot cross into the concurrent child tasks.
        async let routeTask = routePoints(for: activity, in: window)
        async let heartRateTask = heartRate(in: window)
        let (route, heart) = try await (routeTask, heartRateTask)

        return WorkoutDetail(
            route: route,
            averageHeartRate: heart.average,
            maximumHeartRate: heart.maximum,
            energyKilocalories: activity.activeEnergyKilocalories
        )
    }

    /// The route exactly as recorded: HealthKit's own samples for this workout.
    /// When the workout's HealthKit identity is known the query is tied to that
    /// workout, so two overlapping workouts can never mix their routes.
    private func routePoints(for activity: ActivitySample, in window: DateInterval) async throws -> [RoutePoint] {
        let predicate: NSPredicate
        if let uuid = activity.healthKitUUID {
            // A real workout is only ever shown with its own route. If HealthKit
            // cannot produce that workout there is no route to show — falling back
            // to a time window could pick up a different workout's trace, which is
            // exactly the kind of invention this app must never do.
            guard let workout = try? await workout(withUUID: uuid) else { return [] }
            predicate = HKQuery.predicateForObjects(from: workout)
        } else {
            predicate = HKQuery.predicateForSamples(
                withStart: window.start,
                end: window.end,
                options: [.strictStartDate]
            )
        }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workoutRoute(predicate)],
            sortDescriptors: [SortDescriptor(\HKWorkoutRoute.startDate, order: .forward)]
        )

        do {
            let routes = try await descriptor.result(for: store)
            var points: [RoutePoint] = []
            for route in routes {
                for try await location in HKWorkoutRouteQueryDescriptor(route).results(for: store) {
                    points.append(
                        RoutePoint(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                            time: location.timestamp
                        )
                    )
                }
            }
            return points
        } catch let error as HKError where error.code == .errorNoData {
            return []
        } catch {
            // A workout recorded without a route is normal, not an error.
            return []
        }
    }

    private func workout(withUUID uuid: UUID) async throws -> HKWorkout? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObject(with: uuid))],
            sortDescriptors: [],
            limit: 1
        )
        return try await descriptor.result(for: store).first
    }

    private func heartRate(in window: DateInterval) async throws -> (average: Double?, maximum: Double?) {
        let predicate = HKQuery.predicateForSamples(
            withStart: window.start,
            end: window.end,
            options: [.strictStartDate]
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.heartRate), predicate: predicate),
            options: [.discreteAverage, .discreteMax]
        )

        guard let statistics = try? await descriptor.result(for: store) else { return (nil, nil) }
        return (
            statistics.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())),
            statistics.maximumQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))
        )
    }

    private static func map(_ error: Error) -> HealthDataError {
        if let healthError = error as? HKError, healthError.code == .errorAuthorizationNotDetermined {
            return .authorizationNotDetermined
        }
        return .queryFailed(error.localizedDescription)
    }
}
