import SwiftUI

struct ActivityRow: View {
    let activity: ActivitySample
    let formatter: MetricFormatter

    private var accent: Color { Theme.accent(for: .exerciseDuration) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.kind.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.kind.title)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 5) {
                    Text(activity.start.formatted(date: .omitted, time: .shortened))
                    Text("·")
                    Text(formatter.duration(minutes: activity.duration / 60))
                    if let distance = activity.distanceMeters, distance > 0 {
                        Text("·")
                        Text(formatter.string(distance, for: .distance, style: .full))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let elevation = activity.elevationGainMeters, elevation > 0 {
                Label(formatter.string(elevation, for: .elevationGain, style: .compact), systemImage: "mountain.2.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
