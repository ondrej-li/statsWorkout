import Foundation

/// The five headline metrics the app reports for a period.
enum Metric: String, CaseIterable, Identifiable, Codable, Sendable {
    case steps
    case distance
    case elevationGain
    case exerciseDuration
    case activityCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .elevationGain: return "Elevation"
        case .exerciseDuration: return "Exercise"
        case .activityCount: return "Activities"
        }
    }

    var subtitle: String {
        switch self {
        case .steps: return "All-day steps"
        case .distance: return "Covered in workouts"
        case .elevationGain: return "Climbed in workouts"
        case .exerciseDuration: return "Time exercising"
        case .activityCount: return "Workouts recorded"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: return "shoeprints.fill"
        case .distance: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .elevationGain: return "mountain.2.fill"
        case .exerciseDuration: return "timer"
        case .activityCount: return "figure.run"
        }
    }

    var supportsUnit: Bool {
        switch self {
        case .steps, .activityCount: return false
        case .distance, .elevationGain, .exerciseDuration: return true
        }
    }
}
