import Foundation

/// A workout read from Apple Health, normalised for the domain layer.
struct ActivitySample: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: ActivityKind
    let start: Date
    let end: Date
    let distanceMeters: Double?
    let elevationGainMeters: Double?
    let activeEnergyKilocalories: Double?

    init(
        id: UUID = UUID(),
        kind: ActivityKind,
        start: Date,
        end: Date,
        distanceMeters: Double? = nil,
        elevationGainMeters: Double? = nil,
        activeEnergyKilocalories: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.activeEnergyKilocalories = activeEnergyKilocalories
    }

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
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
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .strength: return "Strength"
        case .yoga: return "Yoga"
        case .other: return "Workout"
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
