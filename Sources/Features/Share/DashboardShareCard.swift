import SwiftUI

/// A period's progress, as it was on screen — period, filter and metric included.
struct DashboardShareCard: View {
    let title: String
    let subtitle: String
    let metric: Metric
    let stats: PeriodStats
    let formatter: MetricFormatter
    let periodFormatter: PeriodFormatter
    /// Short labels under the chart, already formatted for the period.
    let axisTicks: [(index: Int, text: String)]

    private var accent: Color { Theme.accent(for: metric) }

    private var otherMetrics: [Metric] {
        Metric.allCases.filter { $0 != metric }
    }

    var body: some View {
        ZStack {
            ShareCardBackground(accent: accent)

            VStack(alignment: .leading, spacing: 0) {
                ShareCardHeader(accent: accent)

                Spacer().frame(height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer().frame(height: 18)

                hero

                Spacer().frame(height: 18)

                chart

                Spacer().frame(height: 22)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 22), GridItem(.flexible(), spacing: 22)],
                    alignment: .leading,
                    spacing: 13
                ) {
                    ForEach(otherMetrics) { item in
                        ShareCardStat(
                            title: item.title,
                            value: formatter.tileString(stats.value(of: item), for: item),
                            systemImage: item.systemImage
                        )
                    }
                }

                Spacer(minLength: 10)

                ShareCardFooter()
            }
            .padding(ShareCard.padding)
        }
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
        .environment(\.colorScheme, .dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(metric.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
            }
            .foregroundStyle(accent)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatter.heroString(stats.value(of: metric), for: metric))
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit = formatter.heroUnit(for: metric) {
                    Text(unit)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            HStack(spacing: 6) {
                deltaPill
                Text(periodFormatter.comparisonCaption(for: stats))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var deltaPill: some View {
        if let delta = stats.delta(of: metric) {
            let isFlat = abs(delta) < 0.005
            let isUp = delta >= 0
            let color: Color = isFlat ? .white.opacity(0.6) : (isUp ? .green : .orange)
            HStack(spacing: 3) {
                Image(systemName: isFlat ? "arrow.right" : (isUp ? "arrow.up.right" : "arrow.down.right"))
                    .font(.system(size: 9, weight: .heavy))
                Text(delta.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .never).locale(formatter.locale)))
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
        }
    }

    private var chart: some View {
        ShareBarChart(
            values: stats.series(of: metric).map { formatter.plotValue($0, for: metric) },
            average: formatter.plotValue(stats.average(of: metric), for: metric),
            labels: axisTicks,
            accent: accent,
            height: 186
        )
    }
}
