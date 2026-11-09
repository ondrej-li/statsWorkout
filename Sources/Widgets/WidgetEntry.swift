import WidgetKit

/// `TimelineEntry` wrapper around the shared `WidgetStats`, plus the title the
/// header shows.
struct StatsEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetFilters
    let stats: WidgetStats
    let rangeTitle: String

    var syncedAt: Date? { stats.syncedAt }

    /// Gallery and placeholder content, drawn from `WidgetPlaceholder`.
    static func placeholder(
        configuration: WidgetFilters,
        formatter: MetricFormatter,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = Date()
    ) -> StatsEntry {
        let stats = WidgetPlaceholder.stats(for: configuration, calendar: calendar, now: now)
        return StatsEntry(
            date: now,
            configuration: configuration,
            stats: WidgetStats(range: stats.range, content: .ready(stats), syncedAt: now),
            rangeTitle: PeriodFormatter(calendar: calendar).rangeTitle(for: stats.range)
        )
    }
}

extension StatsWidgetView {
    /// Convenience for the extension's content closure.
    init(entry: StatsEntry) {
        self.init(configuration: entry.configuration, stats: entry.stats, rangeTitle: entry.rangeTitle)
    }
}
