import Foundation

/// A workout read from Apple Health, normalised for the domain layer.
struct ActivitySample: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let kind: ActivityKind
    let start: Date
    let end: Date
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let stepCount: Double?
    let activeEnergyKilocalories: Double?
    /// HealthKit's identifier for the workout, used to fetch exactly its route.
    let healthKitUUID: UUID?

    init(
        id: UUID = UUID(),
        kind: ActivityKind,
        start: Date,
        end: Date,
        distanceMeters: Double? = nil,
        elevationGainMeters: Double? = nil,
        stepCount: Double? = nil,
        activeEnergyKilocalories: Double? = nil,
        healthKitUUID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.stepCount = stepCount
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.healthKitUUID = healthKitUUID
    }

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    /// Stable across refreshes and cache reloads, so a resolved place name
    /// stays attached to the workout.
    var stableID: String { (healthKitUUID ?? id).uuidString }
}

/// Workout categories the dashboard groups activities into.
enum ActivityKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case running
    case walking
    case cycling
    case hiking
    case swimming
    case strength
    case yoga
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .running: return L10n.t(.kindRun)
        case .walking: return L10n.t(.kindWalk)
        case .cycling: return L10n.t(.kindRide)
        case .hiking: return L10n.t(.kindHike)
        case .swimming: return L10n.t(.kindSwim)
        case .strength: return L10n.t(.kindStrength)
        case .yoga: return L10n.t(.kindYoga)
        case .other: return L10n.t(.kindWorkout)
        }
    }

    var systemImage: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        case .swimming: return "figure.pool.swim"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        case .other: return "figure.mixed.cardio"
        }
    }

    /// Workouts where a distance is meaningful.
    var isDistanceBased: Bool {
        switch self {
        case .running, .walking, .cycling, .hiking, .swimming: return true
        case .strength, .yoga, .other: return false
        }
    }
}

/// Step total for one bucket (an hour or a day, depending on the query).
struct StepSample: Identifiable, Hashable, Sendable {
    let start: Date
    let end: Date
    let count: Double

    var id: Date { start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// A continuously monitored quantity for one bucket, e.g. distance in metres
/// or elevation in metres.
struct QuantitySample: Identifiable, Hashable, Sendable {
    let start: Date
    let end: Date
    let value: Double

    var id: Date { start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}
