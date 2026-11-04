import Foundation

/// Which samples feed the dashboard: everything Health monitors continuously,
/// or only what was recorded inside a workout.
enum DataScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case activities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.t(.scopeAll)
        case .activities: return L10n.t(.scopeActivities)
        }
    }

    var caption: String {
        switch self {
        case .all: return L10n.t(.scopeAllCaption)
        case .activities: return L10n.t(.scopeActivitiesCaption)
        }
    }
}
