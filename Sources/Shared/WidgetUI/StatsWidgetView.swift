import SwiftUI
import WidgetKit

/// The widget's body, laid out for its family.
///
/// Lives in the shared layer rather than in the extension so the layout can be
/// rendered in unit tests and previews: the `StatsWidgetView` here is the exact
/// view the extension installs, not a copy of it.
///
/// Widgets are always on a tinted, Home Screen background, so everything here is
/// drawn with `Color.primary`/`.secondary` rather than the app's fixed palette:
/// text stays legible in both appearances, and iOS can tint the widget when the
/// user asks it to.
struct StatsWidgetView: View {
    let configuration: WidgetFilters
    let stats: WidgetStats
    let rangeTitle: String
    /// Only for previews and tests: `widgetFamily` cannot be written from the
    /// environment, so the size can be forced here to render each one.
    var familyOverride: WidgetFamily?

    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    private var metrics: [Metric] {
        WidgetLayout.metrics(for: family, configuration: configuration)
    }

    var body: some View {
        Group {
            switch stats.content {
            case .ready(let stats):
                ready(stats)
            case .needsApp:
                message(
                    icon: "heart.text.square",
                    title: L10n.t(.widgetNeedsAppTitle),
                    body: L10n.t(.widgetNeedsAppBody)
                )
            case .empty:
                message(
                    icon: "chart.bar.xaxis",
                    title: L10n.t(.widgetEmptyTitle),
                    body: L10n.t(.widgetEmptyBody)
                )
            }
        }
        .containerBackground(for: .widget) {
            ContainerBackground(configuration: configuration)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func ready(_ stats: PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            header

            switch family {
            case .systemSmall:
                small(stats)
            case .systemMedium:
                medium(stats)
            default:
                large(stats)
            }

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tint)
            Text(rangeTitle)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if configuration.scope == .activities {
                Text(L10n.t(.widgetActivitiesBadge))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.10), in: Capsule())
                    .lineLimit(1)
            }
            // Freshly synced data gets a dot; an old one says how old.
            if let syncedAt = stats.syncedAt {
                let age = -syncedAt.timeIntervalSinceNow
                Circle()
                    .fill(age < 20 * 60 ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 5, height: 5)
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Sizes

    private func small(_ stats: PeriodStats) -> some View {
        let metric = configuration.primaryMetric
        return VStack(alignment: .leading, spacing: 3) {
            hero(metric, stats: stats, size: 32)

            HStack(spacing: 4) {
                deltaPill(metric, stats: stats)
                comparisonValue(metric, stats: stats, size: 10)
            }

            Text(metric.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            WidgetSparkline(
                values: stats.buckets.map { $0.totals.value(for: metric) },
                height: WidgetLayout.chartHeight(for: family),
                showsAverage: true
            )

            Text(averageCaption(metric, stats: stats))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ stats: PeriodStats) -> some View {
        let metric = configuration.primaryMetric
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    hero(metric, stats: stats, size: 26)
                    HStack(spacing: 4) {
                        deltaPill(metric, stats: stats)
                        comparisonValue(metric, stats: stats, size: 10)
                    }
                }
                Spacer(minLength: 0)
                metricGrid(stats, excluding: metric, size: 14)
                    .frame(maxWidth: 170)
            }

            WidgetSparkline(
                values: stats.buckets.map { $0.totals.value(for: metric) },
                height: WidgetLayout.chartHeight(for: family),
                showsAverage: true
            )

            HStack(spacing: 6) {
                Text(averageCaption(metric, stats: stats))
                    .layoutPriority(1)
                Spacer(minLength: 0)
                bestCaption(metric, stats: stats)
                    .layoutPriority(0)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func large(_ stats: PeriodStats) -> some View {
        let metric = configuration.primaryMetric
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                hero(metric, stats: stats, size: 34)
                deltaPill(metric, stats: stats)
                comparisonValue(metric, stats: stats, size: 10)
                Spacer(minLength: 0)
            }

            WidgetSparkline(
                values: stats.buckets.map { $0.totals.value(for: metric) },
                height: WidgetLayout.chartHeight(for: family),
                showsAverage: true
            )

            HStack(spacing: 6) {
                Text(averageCaption(metric, stats: stats))
                Spacer(minLength: 0)
                bestCaption(metric, stats: stats)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Divider().opacity(0.4)

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: 9
            ) {
                ForEach(rows(for: stats), id: \.title) { row in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Image(systemName: row.systemImage)
                                .font(.system(size: 8, weight: .semibold))
                            Text(row.title.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .kerning(0.4)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(row.value)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if let delta = row.delta {
                                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 7, weight: .heavy))
                                    .foregroundStyle(delta >= 0 ? Color.green : Color.orange)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            updatedFootnote
        }
    }

    // MARK: - Pieces

    private func hero(_ metric: Metric, stats: PeriodStats, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(formatter.heroString(stats.value(of: metric), for: metric))
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let unit = formatter.heroUnit(for: metric) {
                Text(unit)
                    .font(.system(size: size * 0.34, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func deltaPill(_ metric: Metric, stats: PeriodStats) -> some View {
        if let delta = stats.delta(of: metric) {
            let isFlat = abs(delta) < 0.005
            let isUp = delta >= 0
            HStack(spacing: 2) {
                if !isFlat {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .heavy))
                }
                Text(delta.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .never).locale(formatter.locale)))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isFlat ? Color.secondary : (isUp ? Color.green : Color.orange))
        }
    }

    /// The same number for the comparison window, e.g. "vs 7,490".
    @ViewBuilder
    private func comparisonValue(_ metric: Metric, stats: PeriodStats, size: CGFloat) -> some View {
        let previous = stats.comparisonValue(of: metric)
        if previous > 0 {
            Text(L10n.t(.widgetComparisonValue, formatter.tileString(previous, for: metric)))
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func averageCaption(_ metric: Metric, stats: PeriodStats) -> String {
        L10n.t(
            .widgetAverage,
            formatter.tileString(stats.average(of: metric), for: metric),
            periodFormatter.bucketNoun(for: stats)
        )
    }

    @ViewBuilder
    private func bestCaption(_ metric: Metric, stats: PeriodStats) -> some View {
        if let best = stats.buckets.max(by: { $0.totals.value(for: metric) < $1.totals.value(for: metric) }),
           best.totals.value(for: metric) > 0 {
            Text(L10n.t(.widgetBest, periodFormatter.shortBucketTitle(for: best.bucket, in: stats)))
                .lineLimit(1)
        }
    }

    private func metricGrid(_ stats: PeriodStats, excluding metric: Metric, size: CGFloat) -> some View {
        let items = metrics.filter { $0 != metric }
        return VStack(alignment: .trailing, spacing: 5) {
            ForEach(items) { item in
                HStack(spacing: 4) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(formatter.tileString(stats.value(of: item), for: item))
                        .font(.system(size: size, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private struct Row {
        let title: String
        let value: String
        let systemImage: String
        let delta: Double?
    }

    private func rows(for stats: PeriodStats) -> [Row] {
        metrics
            .filter { $0 != configuration.primaryMetric }
            .map { metric in
                Row(
                    title: metric.title,
                    value: formatter.tileString(stats.value(of: metric), for: metric),
                    systemImage: metric.systemImage,
                    delta: stats.delta(of: metric)
                )
            }
    }

    @ViewBuilder
    private var updatedFootnote: some View {
        if let syncedAt = stats.syncedAt, syncedAt > .distantPast {
            Text(
                L10n.t(
                    .widgetUpdated,
                    syncedAt.formatted(.relative(presentation: .named).locale(formatter.locale))
                )
            )
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
    }

    private func message(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            Text(body)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 3 : 4)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatter: MetricFormatter {
        let preferences = SharedPreferences.load()
        return MetricFormatter(units: preferences.unitPreferences, locale: preferences.locale)
    }

    private var periodFormatter: PeriodFormatter {
        PeriodFormatter(locale: SharedPreferences.load().locale)
    }
}

/// Bars for the period, drawn small: enough to read a trend at a glance.
struct WidgetSparkline: View {
    let values: [Double]
    let height: CGFloat
    var showsAverage: Bool = false

    private var maximum: Double { max(values.max() ?? 0, 0.0001) }
    private var average: Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        GeometryReader { proxy in
            let count = max(values.count, 1)
            let spacing: CGFloat = count > 20 ? 1.5 : 3
            let barWidth = max(1, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        let fraction = max(0, min(1, value / maximum))
                        RoundedRectangle(cornerRadius: min(2, barWidth / 2.5), style: .continuous)
                            .fill(Color.accentColor.opacity(value > 0 ? 0.85 : 0.15))
                            .frame(width: barWidth, height: max(fraction * proxy.size.height, value > 0 ? 2 : 1))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                if showsAverage, average > 0 {
                    let y = proxy.size.height - (average / maximum) * proxy.size.height
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                    .stroke(
                        Color.primary.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                }
            }
        }
        .frame(height: height)
    }
}

/// Soft accent wash behind the widget, so it reads as part of the app.
struct ContainerBackground: View {
    let configuration: WidgetFilters

    var body: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.20),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
