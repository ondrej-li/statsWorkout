import AppIntents
import WidgetKit

/// Everything the widget's configuration screen offers: the same period kinds,
/// data scopes and comparison baselines as the dashboard, plus which metrics to
/// show.
struct StatsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.title" }
    static var description: IntentDescription {
        IntentDescription("widget.intent.description")
    }

    /// How many periods back the widget looks, so "last month" is possible
    /// without a second date picker.
    @Parameter(title: "widget.parameter.period", default: .month)
    var period: WidgetPeriod

    @Parameter(title: "widget.parameter.ago", description: "widget.parameter.ago.description", default: 0)
    var periodsAgo: Int

    @Parameter(title: "widget.parameter.showPrevious", default: false)
    var usesPreviousPeriod: Bool

    @Parameter(title: "widget.parameter.from")
    var customStart: Date?

    @Parameter(title: "widget.parameter.to")
    var customEnd: Date?

    @Parameter(title: "widget.parameter.data", default: .all)
    var scope: WidgetScope

    @Parameter(title: "widget.parameter.compare", default: .previousPeriod)
    var comparison: WidgetComparison

    @Parameter(title: "widget.parameter.mainMetric", default: .steps)
    var primaryMetric: WidgetMetric

    /// The rest of the grid. Small widgets use only the main metric, so this can
    /// stay full without crowding anything.
    @Parameter(title: "widget.parameter.alsoShow", default: [.distance, .exerciseDuration, .elevationGain, .activityCount])
    var extraMetrics: [WidgetMetric]?

    static var parameterSummary: some ParameterSummary {
        When(\.$period, .equalTo, WidgetPeriod.custom) {
            Summary {
                \.$period
                \.$customStart
                \.$customEnd
                \.$scope
                \.$primaryMetric
                \.$extraMetrics
            }
        } otherwise: {
            Summary {
                \.$period
                \.$periodsAgo
                \.$scope
                \.$primaryMetric
                \.$extraMetrics
            }
        }
    }

    // MARK: - Derived

    /// The configuration expressed in the app's own types.
    var configuration: WidgetFilters {
        WidgetFilters(
            period: period.kind,
            periodsAgo: periodsAgo,
            customStart: customStart,
            customEnd: customEnd,
            scope: scope.scope,
            comparison: comparison.mode,
            primaryMetric: primaryMetric.metric,
            extraMetrics: (extraMetrics ?? []).map(\.metric)
        ).validates()
    }
}
