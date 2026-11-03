import Foundation

/// Everything one dashboard load needs, fetched once so both data scopes can be
/// derived without another HealthKit round trip.
struct HealthSamples: Sendable, Equatable {
    /// Workouts in the window.
    var activities: [ActivitySample] = []
    /// Continuous (all-day) monitoring.
    var steps: [StepSample] = []
    var distance: [QuantitySample] = []
    var elevation: [QuantitySample] = []
    /// Steps and distance measured inside the workout windows. HealthKit does
    /// not attach step statistics to workouts, so these come from sample queries
    /// scoped to the workout time ranges.
    var workoutSteps: [QuantitySample] = []
    var workoutDistance: [QuantitySample] = []

    var isEmpty: Bool {
        activities.isEmpty && steps.isEmpty && distance.isEmpty && elevation.isEmpty
    }

    /// `[start, end)` intervals of the workouts, used to scope sample queries.
    var workoutWindows: [DateInterval] {
        activities.map { DateInterval(start: $0.start, end: $0.end) }
    }
}
