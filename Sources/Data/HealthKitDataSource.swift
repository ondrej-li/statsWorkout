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

    func dailySteps(in interval: DateInterval) async throws -> [StepSample] {
        guard isAvailable else { throw HealthDataError.unavailable }
        guard interval.duration > 0 else { return [] }

        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: interval.start)
        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.stepCount), predicate: predicate),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )

        do {
            let collection = try await descriptor.result(for: store)
            var samples: [StepSample] = []
            collection.enumerateStatistics(from: interval.start, to: interval.end) { statistics, _ in
                let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                guard count > 0 else { return }
                samples.append(StepSample(day: statistics.startDate, count: count))
            }
            return samples
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> HealthDataError {
        if let healthError = error as? HKError, healthError.code == .errorAuthorizationNotDetermined {
            return .authorizationNotDetermined
        }
        return .queryFailed(error.localizedDescription)
    }
}
