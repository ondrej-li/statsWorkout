import SwiftUI

/// Tappable summary tile for one metric. Selecting a tile drives the charts.
struct MetricTileView: View {
    let metric: Metric
    let value: String
    let delta: Double?
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color { Theme.accent(for: metric) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: metric.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                    Text(metric.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .kerning(0.6)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(accent)

                Text(value)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)

                DeltaPill(delta: delta)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.13) : Theme.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.opacity(0.6) : Color.primary.opacity(0.05),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(metric.title): \(value)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: 10) {
        MetricTileView(metric: .steps, value: "128k", delta: 0.12, isSelected: true) {}
        MetricTileView(metric: .distance, value: "42.4 km", delta: -0.04, isSelected: false) {}
    }
    .padding()
    .background(Theme.screenBackground)
}
