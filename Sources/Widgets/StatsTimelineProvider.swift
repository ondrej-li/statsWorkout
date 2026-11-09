import AppIntents
import SwiftUI
import WidgetKit

/// Loads the widget's numbers from the app's shared cache and schedules the next
/// refresh.
///
/// No push, no HealthKit: the app writes the shared cache whenever it syncs, and
/// the widget re-reads it every half hour. That keeps the timeline cheap and the
/// numbers within a few minutes of the dashboard.
struct StatsTimelineProvider: AppIntentTimelineProvider {
    static let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry.placeholder(configuration: Self.previewConfiguration, formatter: MetricFormatter())
    }

    func snapshot(for configuration: StatsWidgetIntent, in context: Context) async -> StatsEntry {
        if context.isPreview {
            return StatsEntry.placeholder(configuration: configuration.configuration, formatter: formatter())
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: StatsWidgetIntent, in context: Context) async -> Timeline<StatsEntry> {
        let entry = await entry(for: configuration)
        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(Self.refreshInterval))
        )
    }

    // MARK: - Loading

    func entry(for intent: StatsWidgetIntent) async -> StatsEntry {
        let configuration = intent.configuration
        let stats = await WidgetDataSource().load(configuration: configuration)
        return StatsEntry(
            date: Date(),
            configuration: configuration,
            stats: stats,
            rangeTitle: PeriodFormatter(locale: preferences().locale).rangeTitle(for: stats.range)
        )
    }

    func formatter() -> MetricFormatter {
        let preferences = preferences()
        return MetricFormatter(units: preferences.unitPreferences, locale: preferences.locale)
    }

    private func preferences() -> SharedPreferences { SharedPreferences.load() }

    static var previewConfiguration: WidgetFilters {
        WidgetFilters()
    }
}
