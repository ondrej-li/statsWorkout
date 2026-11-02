import Foundation

/// Which samples feed the dashboard: everything Health monitors continuously,
/// or only what was recorded inside a workout.
enum DataScope: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case activities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All data"
        case .activities: return "Activities"
        }
    }

    var caption: String {
        switch self {
        case .all: return "Continuous monitoring, including workouts"
        case .activities: return "Only samples recorded inside workouts"
        }
    }
}
