import SwiftUI
import WidgetKit

@main
struct StatsWorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatsWidget()
    }
}

/// The one statistics widget: period, scope, comparison and metrics are all
/// configuration, so there is no reason for three flavours of it.
struct StatsWidget: Widget {
    let kind = "StatsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: StatsWidgetIntent.self,
            provider: StatsTimelineProvider()
        ) { entry in
            StatsWidgetView(entry: entry)
        }
        .configurationDisplayName(L10n.t(.widgetTitle))
        .description(L10n.t(.widgetDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
