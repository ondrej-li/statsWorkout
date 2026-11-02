import Charts
import SwiftUI

/// Running total for the period, with the comparison period overlaid.
struct CumulativeChartCard: View {
    let stats: PeriodStats
    let metric: Metric
    let formatter: MetricFormatter
    let periodFormatter: PeriodFormatter
    @Binding var selection: Int?

    private var pointCount: Int {
        stats.isCurrentPeriod ? max(2, stats.elapsedBucketCount) : stats.buckets.count
    }

    private var currentSeries: [Double] {
        Array(stats.cumulativeSeries(of: metric).prefix(pointCount))
    }

    private var previousSeries: [Double] {
        Array(stats.previousCumulativeSeries(of: metric).prefix(pointCount))
    }

    private var hasData: Bool {
        (currentSeries.last ?? 0) > 0 || (previousSeries.last ?? 0) > 0
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                header
                if hasData {
                    chart
                        .frame(height: 165)
                    legend
                } else {
                    EmptyStateView(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No progress to show",
                        message: "There is no \(metric.title.lowercased()) data for this period yet."
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(title: "Progress over time")
            Text("Running total against \(periodFormatter.comparisonCaption(for: stats).replacingOccurrences(of: "vs ", with: ""))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(currentSeries.enumerated()), id: \.offset) { index, value in
                AreaMark(
                    x: .value("Bucket", index),
                    y: .value(metric.title, formatter.plotValue(value, for: metric)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Theme.gradient(for: metric).opacity(0.28))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Bucket", index),
                    y: .value(metric.title, formatter.plotValue(value, for: metric)),
                    series: .value("Series", "current")
                )
                .foregroundStyle(Theme.accent(for: metric))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
            }

            ForEach(Array(previousSeries.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Bucket", index),
                    y: .value(metric.title, formatter.plotValue(value, for: metric)),
                    series: .value("Series", "previous")
                )
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .interpolationMethod(.monotone)
            }

            if let selection, selection >= 0, selection < pointCount {
                RuleMark(x: .value("Selected", selection))
                    .foregroundStyle(Color.primary.opacity(0.22))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        callout(at: selection)
                    }
            }
        }
        .chartXScale(domain: -0.5...(Double(max(pointCount, 1)) - 0.5))
        .chartXSelection(value: $selection)
        .chartXAxis {
            AxisMarks(values: axisIndices) { value in
                AxisTick().foregroundStyle(Color.clear)
                AxisGridLine().foregroundStyle(Color.clear)
                AxisValueLabel {
                    if let index = value.as(Int.self) {
                        Text(xAxisLabel(for: index))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(formatter.axisLabel(number, for: metric))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityLabel("Cumulative \(metric.title.lowercased()) chart")
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.accent(for: metric), dashed: false, title: "This period")
            legendItem(color: .secondary, dashed: true, title: stats.comparisonMode == .previousPeriod ? "Previous period" : "Last year")
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, dashed: Bool, title: String) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 2.5)
                .opacity(dashed ? 0.7 : 1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func callout(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(bucketTitle(at: index))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(formatter.string(currentValue(at: index), for: metric))
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(formatter.string(previousValue(at: index), for: metric))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10))
        }
    }

    // MARK: - Helpers

    private func currentValue(at index: Int) -> Double {
        guard index < currentSeries.count else { return 0 }
        return formatter.plotValue(currentSeries[index], for: metric)
    }

    private func previousValue(at index: Int) -> Double {
        guard index < previousSeries.count else { return 0 }
        return formatter.plotValue(previousSeries[index], for: metric)
    }

    private func bucketTitle(at index: Int) -> String {
        guard index < stats.buckets.count else { return "" }
        return periodFormatter.bucketTitle(for: stats.buckets[index].bucket, in: stats)
    }

    private var axisIndices: [Int] {
        guard pointCount > 0 else { return [] }
        let step = max(1, Int((Double(pointCount) / 5).rounded(.up)))
        return stride(from: 0, to: pointCount, by: step).map { $0 }
    }

    private func xAxisLabel(for index: Int) -> String {
        guard index < stats.buckets.count else { return "" }
        return periodFormatter.bucketAxisLabel(for: stats.buckets[index].bucket, in: stats)
    }
}

#if DEBUG
#Preview("Cumulative chart") {
    let stats = PreviewStats.sample()
    CumulativeChartCard(
        stats: stats,
        metric: .distance,
        formatter: MetricFormatter(),
        periodFormatter: PeriodFormatter(),
        selection: .constant(1)
    )
    .padding()
    .background(Theme.screenBackground)
}

#endif
