import SwiftUI

/// A workout the way the Health app presents one: what it was, where it
/// happened, the numbers, and the splits for distance activities.
struct ActivityDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: ActivityDetailViewModel

    init(activity: ActivitySample) {
        _model = State(initialValue: ActivityDetailViewModel(activity: activity, environment: .placeholder))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if model.detail.hasRoute {
                    WorkoutRouteMap(route: model.detail.route)
                }
                metrics
                if !model.splits.isEmpty {
                    splitsCard
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .navigationTitle(model.activity.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    // MARK: - Header

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: model.activity.kind.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent(for: .exerciseDuration))
                        .frame(width: 46, height: 46)
                        .background(Theme.accent(for: .exerciseDuration).opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayTitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(timeRange)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }

                Text(model.title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dayTitle: String {
        model.activity.start.formatted(
            .dateTime.weekday(.wide).day().month(.wide).year()
                .locale(environment.calendar.locale ?? .autoupdatingCurrent)
        )
    }

    private var timeRange: String {
        let start = model.activity.start.formatted(date: .omitted, time: .shortened)
        let end = model.activity.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    // MARK: - Metrics

    private var metrics: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Details")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    metric("Duration", model.formatter.duration(minutes: model.activity.duration / 60), "timer")
                    if let distance = model.activity.distanceMeters, distance > 0 {
                        metric("Distance", model.formatter.string(distance, for: .distance), "point.topleft.down.to.point.bottomright.curvepath")
                        if let pace = averagePace {
                            metric("Avg pace", pace, "speedometer")
                        }
                    }
                    if let elevation = model.activity.elevationGainMeters, elevation > 0 {
                        metric("Elevation gain", model.formatter.string(elevation, for: .elevationGain), "mountain.2")
                    }
                    if let steps = model.activity.stepCount, steps > 0 {
                        metric("Steps", model.formatter.heroString(steps, for: .steps), "shoeprints.fill")
                    }
                    if let energy = model.detail.energyKilocalories ?? model.activity.activeEnergyKilocalories, energy > 0 {
                        metric("Active energy", "\(Int(energy.rounded())) kcal", "flame")
                    }
                    if let heart = model.detail.averageHeartRate {
                        metric("Avg heart rate", model.formatter.heartRate(heart), "heart")
                    }
                    if let heart = model.detail.maximumHeartRate {
                        metric("Max heart rate", model.formatter.heartRate(heart), "heart.circle")
                    }
                }
            }
        }
    }

    private var averagePace: String? {
        guard let distance = model.activity.distanceMeters, distance > 0, model.activity.duration > 0 else {
            return nil
        }
        let unit = environment.settings.distanceUnit
        let units = unit.value(fromMeters: distance)
        guard units > 0 else { return nil }
        return model.formatter.pace(model.activity.duration / units, unit: unit)
    }

    private func metric(_ title: String, _ value: String, _ systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Splits

    private var splitsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "Splits")
                ForEach(model.splits) { split in
                    HStack(spacing: 10) {
                        Text(model.formatter.splitDistance(split.distance, unit: environment.settings.distanceUnit))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .frame(width: 66, alignment: .leading)

                        Text(model.formatter.duration(minutes: split.duration / 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer(minLength: 0)

                        Text(model.formatter.pace(split.pace, unit: environment.settings.distanceUnit))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    if split.id != model.splits.last?.id {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ActivityDetailView(
            activity: ActivitySample(
                kind: .running,
                start: Date(timeIntervalSinceNow: -3_600),
                end: Date(),
                distanceMeters: 9_400,
                elevationGainMeters: 120,
                stepCount: 11_200,
                activeEnergyKilocalories: 610
            )
        )
        .environment(AppEnvironment.preview())
    }
}
#endif
