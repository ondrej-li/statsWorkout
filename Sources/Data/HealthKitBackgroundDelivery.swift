import Foundation
import HealthKit

/// Keeps the app informed while it is not open.
///
/// HealthKit wakes the app when the observed types change, provided background
/// delivery is enabled for them and an observer query is running. The handler
/// only signals "something changed" — the next refresh re-reads a short overlap
/// window, so the work stays proportional to what actually changed.
final class HealthKitBackgroundDelivery: @unchecked Sendable {
    private let store: HKHealthStore
    private let onChange: @Sendable (HKObjectType) -> Void
    private let lock = NSLock()
    private var observers: [HKObserverQuery] = []
    private var isRunning = false

    init(
        store: HKHealthStore = HKHealthStore(),
        onChange: @escaping @Sendable (HKObjectType) -> Void
    ) {
        self.store = store
        self.onChange = onChange
    }

    var observedTypes: [HKSampleType] {
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

    /// Safe to call repeatedly; only the first call installs observers.
    func start() {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        isRunning = true
        lock.unlock()

        guard HKHealthStore.isHealthDataAvailable() else { return }

        let types = observedTypes
        Task { [weak self] in
            guard let self else { return }
            for type in types {
                // Errors are expected when the user denied access to a type; the
                // foreground refresh still works, so they are not surfaced.
                try? await store.enableBackgroundDelivery(for: type, frequency: .immediate)
                self.installObserver(for: type)
            }
        }
    }

    func stop() {
        lock.lock()
        let queries = observers
        observers.removeAll()
        isRunning = false
        lock.unlock()

        queries.forEach(store.stop)
        for type in observedTypes {
            store.disableBackgroundDelivery(for: type) { _, _ in }
        }
    }

    private func installObserver(for type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [onChange] _, completion, error in
            if error == nil {
                onChange(type)
            }
            // Must be called, otherwise HealthKit keeps re-notifying.
            completion()
        }
        store.execute(query)

        lock.lock()
        observers.append(query)
        lock.unlock()
    }
}
