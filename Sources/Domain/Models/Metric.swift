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
        case .steps: return L10n.t(.metricSteps)
        case .distance: return L10n.t(.metricDistance)
        case .elevationGain: return L10n.t(.metricElevation)
        case .exerciseDuration: return L10n.t(.metricExercise)
        case .activityCount: return L10n.t(.metricActivities)
        }
    }

    var subtitle: String {
        switch self {
        case .steps: return L10n.t(.metricStepsSubtitle)
        case .distance: return L10n.t(.metricDistanceSubtitle)
        case .elevationGain: return L10n.t(.metricElevationSubtitle)
        case .exerciseDuration: return L10n.t(.metricExerciseSubtitle)
        case .activityCount: return L10n.t(.metricActivitiesSubtitle)
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
}
