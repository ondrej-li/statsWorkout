import AppIntents
import Foundation
import Foundation

/// The app's period kinds, as widget configuration options.
///
/// A separate `AppEnum` rather than `PeriodKind` itself: widget options need a
/// stable string identity and localized titles, and the domain type should not
/// learn about WidgetKit.
enum WidgetPeriod: String, AppEnum {
    case day
    case last24Hours
    case week
    case month
    case quarter
    case year
    case custom

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.type.period")
    }

    static var caseDisplayRepresentations: [WidgetPeriod: DisplayRepresentation] {
        [
            .day: DisplayRepresentation(title: "widget.period.day"),
            .last24Hours: DisplayRepresentation(title: "widget.period.last24Hours"),
            .week: DisplayRepresentation(title: "widget.period.week"),
            .month: DisplayRepresentation(title: "widget.period.month"),
            .quarter: DisplayRepresentation(title: "widget.period.quarter"),
            .year: DisplayRepresentation(title: "widget.period.year"),
            .custom: DisplayRepresentation(title: "widget.period.custom")
        ]
    }

    var kind: PeriodKind {
        switch self {
        case .day: return .day
        case .last24Hours: return .last24Hours
        case .week: return .week
        case .month: return .month
        case .quarter: return .quarter
        case .year: return .year
        case .custom: return .custom
        }
    }

    /// The app's own title, so a configured widget is labelled the same way.
    var title: String { kind.title }
}

enum WidgetScope: String, AppEnum {
    case all
    case activities

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.type.data")
    }

    static var caseDisplayRepresentations: [WidgetScope: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "widget.scope.all", subtitle: "widget.scope.all.caption"),
            .activities: DisplayRepresentation(title: "widget.scope.activities", subtitle: "widget.scope.activities.caption")
        ]
    }

    var scope: DataScope {
        switch self {
        case .all: return .all
        case .activities: return .activities
        }
    }

    var shortTitle: String {
        switch self {
        case .all: return L10n.t(.scopeAll)
        case .activities: return L10n.t(.scopeActivities)
        }
    }
}

enum WidgetComparison: String, AppEnum {
    case previousPeriod
    case samePeriodLastYear

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.type.compare")
    }

    static var caseDisplayRepresentations: [WidgetComparison: DisplayRepresentation] {
        [
            .previousPeriod: DisplayRepresentation(title: "widget.comparison.previous"),
            .samePeriodLastYear: DisplayRepresentation(title: "widget.comparison.lastYear")
        ]
    }

    var mode: ComparisonMode {
        switch self {
        case .previousPeriod: return .previousPeriod
        case .samePeriodLastYear: return .samePeriodLastYear
        }
    }
}

/// A metric the user can put on a widget.
enum WidgetMetric: String, AppEnum, CaseIterable {
    case steps
    case distance
    case elevationGain
    case exerciseDuration
    case activityCount

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.type.metric")
    }

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] {
        [
            .steps: DisplayRepresentation(title: "widget.metric.steps"),
            .distance: DisplayRepresentation(title: "widget.metric.distance"),
            .elevationGain: DisplayRepresentation(title: "widget.metric.elevation"),
            .exerciseDuration: DisplayRepresentation(title: "widget.metric.exercise"),
            .activityCount: DisplayRepresentation(title: "widget.metric.activities")
        ]
    }

    var metric: Metric {
        switch self {
        case .steps: return .steps
        case .distance: return .distance
        case .elevationGain: return .elevationGain
        case .exerciseDuration: return .exerciseDuration
        case .activityCount: return .activityCount
        }
    }
}
