import SwiftUI

/// A workout the way the Health app presents one: what it was, where it
/// happened, the numbers, and the splits for distance activities.
struct ActivityDetailView: View {
    @State private var model: ActivityDetailViewModel
    @State private var shareItem: ShareItem?
    @State private var shareFailed = false

    /// The environment is passed in, not read from `@Environment`: a view model
    /// built in `init` cannot see environment values, and a placeholder here
    /// once meant every route came from the demo generator.
    init(activity: ActivitySample, environment: AppEnvironment) {
        _model = State(
            initialValue: ActivityDetailViewModel(activity: activity, environment: environment)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if model.isDemo && !ScreenshotRoute.hidesDemoLabels {
                    demoBanner
                }
                header
                routeSection
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let item = model.shareItem() {
                        shareItem = item
                    } else {
                        shareFailed = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.t(.shareButton))
                .disabled(model.phase == .loading)
            }
        }
        .sharePresentation(item: $shareItem, failure: $shareFailed)
        .task { await model.load() }
    }

    /// Demo workouts invent their numbers and route; say so up front rather
    /// than leaving it to a caption under the map.
    private var demoBanner: some View {
        Label(L10n.t(.demoBanner), systemImage: "flask.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private var dayTitle: String { model.dateText }
    private var timeRange: String { model.timeText }

    // MARK: - Route

    /// Says where the trace came from, so a generated route can never pass for a
    /// recording. Absence is stated too: HealthKit stores routes only for
    /// workouts recorded by a watch or an app that writes them.
    @ViewBuilder
    private var routeSection: some View {
        switch model.provenance {
        case .loading:
            SkeletonCard(height: 240)
        case .demo:
            VStack(alignment: .leading, spacing: 6) {
                WorkoutRouteMap(route: model.detail.route)
                if !ScreenshotRoute.hidesDemoLabels {
                    Label(L10n.t(.detailRouteDemo), systemImage: "flask")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    routeDetails
                }
            }
        case .recorded:
            VStack(alignment: .leading, spacing: 6) {
                WorkoutRouteMap(route: model.detail.route)
                Label(L10n.t(.detailRouteRecorded), systemImage: "checkmark.seal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                routeDetails
            }
        case .notRecorded:
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.t(.detailRouteNoneTitle), systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.t(.detailRouteNoneBody))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let count = model.detail.routeSamplesInWindow {
                        Text(count == 0
                             ? L10n.t(.detailRouteNoneZero)
                             : L10n.t(.detailRouteNoneUnlinked, count))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    HStack(spacing: 10) {
                        Button(L10n.t(.detailRouteGrant)) {
                            Task { await model.requestRouteAccess() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        Button(L10n.t(.actionReload)) {
                            Task { await model.reload() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var routeDetails: some View {
        DisclosureGroup(L10n.t(.detailRouteDetails)) {
            VStack(alignment: .leading, spacing: 6) {
                detailRow(L10n.t(.detailRouteSource), model.isDemo ? L10n.t(.demoRouteSource) : L10n.t(.settingsHealth))
                if case let .recorded(points) = model.provenance {
                    detailRow(L10n.t(.detailRoutePoints), points.formatted(.number.locale(model.locale)))
                }
                if let range = model.traceTimeRange {
                    detailRow(L10n.t(.detailRouteTraceTime), range)
                }
                detailRow(
                    L10n.t(.detailRouteWorkout),
                    model.activity.start.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(model.locale))
                )
                if let count = model.detail.routeSamplesInWindow {
                    detailRow(L10n.t(.detailRouteRoutesInWindow), count.formatted(.number.locale(model.locale)))
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    // MARK: - Metrics

    private var metrics: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: L10n.t(.detailSection))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(model.metricRows) { row in
                        metric(row.title, row.value, row.systemImage)
                    }
                }
            }
        }
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
                SectionLabel(title: L10n.t(.detailSplits))
                ForEach(model.splits) { split in
                    HStack(spacing: 10) {
                        Text(model.formatter.splitDistance(split.distance, unit: model.distanceUnit))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .frame(width: 66, alignment: .leading)

                        Text(model.formatter.duration(minutes: split.duration / 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer(minLength: 0)

                        Text(model.formatter.pace(split.pace, unit: model.distanceUnit))
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
    let environment = AppEnvironment.preview()
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
            ),
            environment: environment
        )
        .environment(environment)
    }
}
#endif
