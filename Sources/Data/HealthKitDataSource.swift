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
        granularity: StepGranularity
    ) async throws -> HKStatisticsCollection {
        let calendar = Calendar.current
        let predicate = HKQuery.predicateForSamples(
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

    private static func map(_ error: Error) -> HealthDataError {
        if let healthError = error as? HKError, healthError.code == .errorAuthorizationNotDetermined {
            return .authorizationNotDetermined
        }
        return .queryFailed(error.localizedDescription)
    }
}
