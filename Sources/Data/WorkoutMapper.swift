import Foundation
import HealthKit

/// Maps HealthKit workouts onto the app's domain types.
enum WorkoutMapper {
    /// Standard riser height used when a workout only reports flights climbed.
    static let metersPerFlight: Double = 3

    static func kind(for type: HKWorkoutActivityType) -> ActivityKind {
        switch type {
        case .running: return .running
        case .walking: return .walking
        case .cycling, .handCycling: return .cycling
        case .hiking: return .hiking
        case .swimming: return .swimming
        case .traditionalStrengthTraining, .functionalStrengthTraining, .crossTraining: return .strength
        case .yoga: return .yoga
        default: return .other
        }
    }

    static func activity(from workout: HKWorkout) -> ActivitySample {
        let activityKind = kind(for: workout.workoutActivityType)
        return ActivitySample(
            kind: activityKind,
            start: workout.startDate,
            end: workout.endDate,
            distanceMeters: distance(for: workout, kind: activityKind),
            elevationGainMeters: elevationGain(for: workout),
            activeEnergyKilocalories: workout
                .statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
        )
    }

    static func distance(for workout: HKWorkout, kind: ActivityKind) -> Double? {
        for type in distanceTypes(for: kind) {
            if let meters = workout.statistics(for: type)?.sumQuantity()?.doubleValue(for: .meter()), meters > 0 {
                return meters
            }
        }
        return workout.totalDistance?.doubleValue(for: .meter())
    }

    /// Elevation ascended, from workout metadata when available, otherwise estimated
    /// from flights climbed.
    static func elevationGain(for workout: HKWorkout) -> Double? {
        if let quantity = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            return max(0, quantity.doubleValue(for: .meter()))
        }
        if let flights = workout.statistics(for: HKQuantityType(.flightsClimbed))?
            .sumQuantity()?
            .doubleValue(for: .count()), flights > 0 {
            return flights * metersPerFlight
        }
        return nil
    }

    static func distanceTypes(for kind: ActivityKind) -> [HKQuantityType] {
        switch kind {
        case .running, .walking, .hiking:
            return [HKQuantityType(.distanceWalkingRunning)]
        case .cycling:
            return [HKQuantityType(.distanceCycling), HKQuantityType(.distanceWalkingRunning)]
        case .swimming:
            return [HKQuantityType(.distanceSwimming)]
        case .strength, .yoga, .other:
            return []
        }
    }
}
