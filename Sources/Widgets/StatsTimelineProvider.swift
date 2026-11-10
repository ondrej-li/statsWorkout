import AppIntents
import SwiftUI
import WidgetKit

/// Loads the widget's numbers and schedules the next refresh.
///
/// The widget reads Apple Health itself, so it is current while the user is
/// walking or working out with the app closed; the app's shared cache is the
/// fallback when Health access is missing, and the source of everything older
/// than the current period. iOS grants a widget a limited number of refreshes,
/// so the interval is deliberately modest — `WidgetCenter` reloads are triggered
/// from the app whenever it syncs in the foreground or in the background.
struct StatsTimelineProvider: AppIntentTimelineProvider {
    /// The shortest interval iOS honours in practice without a reload signal.
    static let refreshInterval: TimeInterval = 15 * 60

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
        let preferences = preferences()
        let stats = await dataSource(for: preferences).load(configuration: configuration)
        return StatsEntry(
            date: Date(),
            configuration: configuration,
            stats: stats,
            rangeTitle: PeriodFormatter(locale: preferences.locale).rangeTitle(for: stats.range)
        )
    }

    /// Demo mode is mirrored from the app so the widget shows the same thing the
    /// dashboard does; otherwise the widget reads Health directly.
    private func dataSource(for preferences: SharedPreferences) -> WidgetDataSource {
        preferences.useMockData
            ? WidgetDataSource(liveSource: MockHealthDataSource(), sourceKey: "mock")
            : WidgetDataSource(liveSource: HealthKitDataSource(), sourceKey: "healthkit")
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
