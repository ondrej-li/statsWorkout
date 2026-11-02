import Charts
import SwiftUI

/// Bar chart for one metric with pinch/button zoom and press-and-drag value inspection.
struct MetricChartCard: View {
    let stats: PeriodStats
    let metric: Metric
    let formatter: MetricFormatter
    let periodFormatter: PeriodFormatter
    @Binding var selection: Int?

    @State private var visibleCount: Int = 0
    @State private var scrollX: Double = 0
    @State private var zoomAnchorCount: Int?

    private var bucketCount: Int { stats.buckets.count }
    private var minVisible: Int { max(2, min(5, bucketCount)) }
    private var isZoomed: Bool { visibleCount < bucketCount }
    private var hasData: Bool { stats.totals.value(for: metric) > 0 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                header
                if hasData {
                    chart
                        .frame(height: 210)
                    footer
                } else {
                    EmptyStateView(
                        systemImage: metric.systemImage,
                        title: "Nothing here yet",
                        message: "No \(metric.title.lowercased()) recorded in this period."
                    )
                }
            }
        }
        .onAppear {
            if visibleCount == 0 { visibleCount = bucketCount }
        }
        .onChange(of: bucketCount) { _, newValue in
            visibleCount = newValue
            scrollX = 0
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(title: "\(metric.title) by \(granularityTitle)")
                Text(unitCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                zoomButton("minus.magnifyingglass", label: "Zoom out") {
                    setVisibleCount(Int((Double(visibleCount) * 0.65).rounded()))
                }
                .disabled(visibleCount <= minVisible)

                zoomButton("plus.magnifyingglass", label: "Zoom in") {
                    setVisibleCount(Int((Double(visibleCount) / 0.65).rounded()))
                }
                .disabled(visibleCount >= bucketCount)

                zoomButton("arrow.counterclockwise", label: "Reset zoom") {
                    setVisibleCount(bucketCount)
                    scrollX = 0
                }
                .disabled(!isZoomed)
                .opacity(isZoomed ? 1 : 0.35)
            }
        }
    }

    private func zoomButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(stats.buckets) { item in
                BarMark(
                    x: .value("Bucket", item.bucket.index),
                    y: .value(metric.title, plotValue(item))
                )
                .foregroundStyle(Theme.gradient(for: metric))
                .cornerRadius(5)
                .opacity(barOpacity(for: item.bucket.index))
            }

            if averageValue > 0 {
                RuleMark(y: .value("Average", averageValue))
                    .foregroundStyle(Color.secondary.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }

            if let selection, let item = stats.buckets.first(where: { $0.bucket.index == selection }) {
                RuleMark(x: .value("Selected", selection))
                    .foregroundStyle(Color.primary.opacity(0.22))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(
                        position: .top,
                        spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        callout(for: item)
                    }
            }
        }
        .chartXScale(domain: -0.5...(Double(max(bucketCount, 1)) - 0.5))
        .chartYScale(domain: 0...(max(maxValue * 1.18, 1)))
        .chartXSelection(value: $selection)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: max(visibleCount, minVisible))
        .chartScrollPosition(x: $scrollX)
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
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
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
        .simultaneousGesture(pinchToZoom)
        .accessibilityLabel("\(metric.title) chart, \(periodFormatter.rangeTitle(for: stats.range))")
        .accessibilityValue(accessibilityValue)
    }

    private var pinchToZoom: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                if zoomAnchorCount == nil { zoomAnchorCount = visibleCount }
                guard let anchor = zoomAnchorCount else { return }
                let proposed = Double(anchor) / max(value.magnification, 0.05)
                let clamped = min(bucketCount, max(minVisible, Int(proposed.rounded())))
                if clamped != visibleCount { visibleCount = clamped }
            }
            .onEnded { _ in zoomAnchorCount = nil }
    }

    private func callout(for item: BucketStats) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(periodFormatter.bucketTitle(for: item.bucket, in: stats))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatter.string(item.totals.value(for: metric), for: metric))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
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

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: isZoomed ? "arrow.left.and.right" : "hand.draw")
                .font(.caption2)
            Text(isZoomed ? "Drag to pan · pinch to zoom · tap for values" : "Pinch to zoom · tap a bar for details")
                .font(.caption2)
            Spacer(minLength: 0)
            if isZoomed {
                Text("\(visibleCount)/\(bucketCount)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - Helpers

    private var granularityTitle: String {
        switch stats.granularity {
        case .day: return stats.range.kind == .week ? "day" : "day"
        case .week: return "week"
        case .month: return "month"
        }
    }

    private var unitCaption: String {
        if let symbol = formatter.unitSymbol(for: metric) {
            return "\(metric.subtitle) · \(symbol)"
        }
        return metric.subtitle
    }

    private func plotValue(_ item: BucketStats) -> Double {
        formatter.plotValue(item.totals.value(for: metric), for: metric)
    }

    private var maxValue: Double {
        stats.buckets.map(plotValue).max() ?? 0
    }

    private var averageValue: Double {
        formatter.plotValue(stats.average(of: metric), for: metric)
    }

    private func barOpacity(for index: Int) -> Double {
        guard let selection else { return 1 }
        return selection == index ? 1 : 0.45
    }

    private var axisIndices: [Int] {
        guard bucketCount > 0 else { return [] }
        let step = max(1, Int((Double(max(visibleCount, minVisible)) / 6).rounded(.up)))
        return stride(from: 0, to: bucketCount, by: step).map { $0 }
    }

    private func xAxisLabel(for index: Int) -> String {
        guard let item = stats.buckets.first(where: { $0.bucket.index == index }) else { return "" }
        return periodFormatter.bucketAxisLabel(for: item.bucket, in: stats)
    }

    private func setVisibleCount(_ proposed: Int) {
        visibleCount = min(bucketCount, max(minVisible, proposed))
    }

    private var accessibilityValue: String {
        guard let selection, let item = stats.buckets.first(where: { $0.bucket.index == selection }) else {
            return "Total \(formatter.string(stats.totals.value(for: metric), for: metric))"
        }
        return "\(periodFormatter.bucketTitle(for: item.bucket, in: stats)): \(formatter.string(item.totals.value(for: metric), for: metric))"
    }
}

#Preview("Metric chart") {
    let stats = PreviewStats.sample()
    MetricChartCard(
        stats: stats,
        metric: .steps,
        formatter: MetricFormatter(),
        periodFormatter: PeriodFormatter(),
        selection: .constant(1)
    )
    .padding()
    .background(Theme.screenBackground)
}
