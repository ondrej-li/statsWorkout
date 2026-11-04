import SwiftUI

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: DashboardViewModel
    @State private var isShowingCustomRange = false

    init(environment: AppEnvironment) {
        _model = State(initialValue: DashboardViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        rangeHeader
                            .id("top")
                        PeriodPickerBar(selection: model.periodKind) { model.select($0) }
                        scopePicker
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .task(id: ScreenshotRoute.section) {
                    guard let section = ScreenshotRoute.section else { return }
                    // Let the dashboard finish loading before jumping.
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo(section, anchor: .top)
                }
            }
            .scrollIndicators(.hidden)
            .background { background }
            .navigationTitle(L10n.t(.tabStats))
            // Chart shots are taken scrolled; a compact bar reads better than a
            // collapsed large title over the first card.
            .navigationBarTitleDisplayMode(ScreenshotRoute.section == nil ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t(.actionToday)) {
                        withAnimation(.snappy) { model.goToNow() }
                    }
                    .disabled(model.isCurrentPeriod)
                }
            }
            .task(id: model.loadRequest) { await model.load() }
            .task {
                // HealthKit wakes the app in the background; the observers only
                // need installing once access exists.
                if !environment.settings.useMockData {
                    environment.startBackgroundDelivery()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.load() }
            }
            .onChange(of: environment.healthUpdates) { _, _ in
                Task { await model.load() }
            }
            .onChange(of: model.recentActivities) { _, activities in
                Task { await environment.resolveWorkoutPlaces(for: activities, limit: 4) }
            }
            .refreshable { await model.load(forceRefresh: true) }
            .onChange(of: model.periodKind) { _, kind in
                if kind == .custom { isShowingCustomRange = true }
            }
            .sheet(isPresented: $isShowingCustomRange) {
                CustomRangeSheet(start: model.customStart, end: model.customEnd) { start, end in
                    model.applyCustomRange(start: start, end: end)
                }
            }
        }
    }

    // MARK: - Header

    private var rangeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.rangeTitle)
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
                HStack(spacing: 6) {
                    if let stats = model.stats {
                        Text(model.periodFormatter.progressCaption(for: stats))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if environment.settings.useMockData {
                        Label(L10n.t(.demoBadge), systemImage: "flask")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                            .accessibilityLabel(L10n.t(.demoBadgeA11y))
                    }
                }
            }
            Spacer()
            HStack(spacing: 6) {
                chevron("chevron.left", label: L10n.t(.actionPreviousPeriod)) { model.step(by: -1) }
                    .disabled(!model.canStepBackward)
                chevron("chevron.right", label: L10n.t(.actionNextPeriod)) { model.step(by: 1) }
                    .disabled(!model.canStepForward)
            }
        }
        .padding(.top, 4)
    }

    private func chevron(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var scopePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(L10n.t(.settingsDataSource), selection: Binding(
                get: { model.dataScope },
                set: { model.dataScope = $0 }
            )) {
                ForEach(DataScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Text(model.dataScope.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .failed(let message):
            errorCard(message)
        case .needsAuthorization:
            permissionCard
        default:
            if let stats = model.stats {
                heroCard(stats)
                metricGrid(stats)
                MetricChartCard(
                    stats: stats,
                    metric: model.metric,
                    formatter: model.formatter,
                    periodFormatter: model.periodFormatter,
                    selection: selectionBinding
                )
                .id("charts")
                CumulativeChartCard(
                    stats: stats,
                    metric: model.metric,
                    formatter: model.formatter,
                    periodFormatter: model.periodFormatter,
                    selection: selectionBinding
                )
                .id("progress")
                recentActivitiesCard(stats)
                    .id("activities")
                if model.showsPermissionHint || model.healthAccessUnavailable {
                    permissionCard
                }
            } else {
                loadingPlaceholder
            }
        }
    }

    private var selectionBinding: Binding<Int?> {
        Binding(
            get: { model.selectedBucketIndex },
            set: { model.selectedBucketIndex = $0 }
        )
    }

    private func heroCard(_ stats: PeriodStats) -> some View {
        let metric = model.metric
        let formatter = model.formatter

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(title: L10n.t(.dashboardTotal, metric.title))
                    Spacer()
                    Image(systemName: metric.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent(for: metric))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formatter.heroString(stats.value(of: metric), for: metric))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .contentTransition(.numericText())
                    if let unit = formatter.heroUnit(for: metric) {
                        Text(unit)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    DeltaPill(delta: stats.delta(of: metric))
                    Text(model.periodFormatter.comparisonCaption(for: stats))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                Divider().opacity(0.5)

                HStack(spacing: 0) {
                    heroStat(
                        L10n.t(.dashboardAveragePer, model.periodFormatter.bucketNoun(for: stats)),
                        formatter.tileString(stats.average(of: metric), for: metric)
                    )
                    heroStat(L10n.t(.dashboardActivities), "\(stats.totals.activityCount)")
                    heroStat(L10n.t(.dashboardBest), bestBucketCaption(stats))
                }
            }
        }
    }

    private func heroStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bestBucketCaption(_ stats: PeriodStats) -> String {
        guard let best = stats.buckets.max(by: { $0.totals.value(for: model.metric) < $1.totals.value(for: model.metric) }),
              best.totals.value(for: model.metric) > 0 else {
            return "—"
        }
        return model.periodFormatter.shortBucketTitle(for: best.bucket, in: stats)
    }

    private func metricGrid(_ stats: PeriodStats) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                tile(.steps, stats)
                tile(.distance, stats)
            }
            GridRow {
                tile(.elevationGain, stats)
                tile(.exerciseDuration, stats)
            }
            GridRow {
                tile(.activityCount, stats)
                    .gridCellColumns(2)
            }
        }
    }

    private func tile(_ metric: Metric, _ stats: PeriodStats) -> some View {
        MetricTileView(
            metric: metric,
            value: model.formatter.tileString(stats.value(of: metric), for: metric),
            delta: stats.delta(of: metric),
            isSelected: model.metric == metric
        ) {
            withAnimation(.snappy(duration: 0.2)) { model.selectMetric(metric) }
        }
    }

    private func recentActivitiesCard(_ stats: PeriodStats) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(title: L10n.t(.recentSection))
                    Spacer()
                    Text(L10n.t(.recentInPeriod, stats.totals.activityCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let recent = Array(model.recentActivities.prefix(4))
                if recent.isEmpty {
                    Text(L10n.t(.recentEmpty))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(recent) { activity in
                        ActivityRow(
                            activity: activity,
                            title: environment.workoutTitle(for: activity),
                            formatter: model.formatter
                        )
                        if activity.id != recent.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private var permissionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    model.healthAccessUnavailable ? L10n.t(.healthUnavailableTitle) : L10n.t(.healthConnectTitle),
                    systemImage: model.healthAccessUnavailable ? "heart.slash.fill" : "heart.text.square.fill"
                )
                .font(.headline)

                Text(model.healthAccessUnavailable ? L10n.t(.healthUnavailableBody) : L10n.t(.healthConnectBody))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !model.healthAccessUnavailable {
                    Button {
                        Task { await model.requestHealthAccess() }
                    } label: {
                        Text(model.isRequestingAuthorization ? L10n.t(.actionRequesting) : L10n.t(.actionAllowAccess))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRequestingAuthorization)
                }
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t(.errorTitle), systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L10n.t(.actionRetry)) {
                    Task { await model.load() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 14) {
            SkeletonCard(height: 190)
            SkeletonCard(height: 130)
            SkeletonCard(height: 300)
        }
    }

    private var background: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accent(for: model.metric).opacity(0.16), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: model.metric)
        }
    }
}

struct CustomRangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var start: Date
    @State private var end: Date
    private let onApply: (Date, Date) -> Void

    init(start: Date, end: Date, onApply: @escaping (Date, Date) -> Void) {
        _start = State(initialValue: start)
        _end = State(initialValue: end)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t(.rangeFrom)) {
                    DatePicker(L10n.t(.rangeStart), selection: $start, displayedComponents: .date)
                }
                Section(L10n.t(.rangeTo)) {
                    DatePicker(L10n.t(.rangeEnd), selection: $end, in: start..., displayedComponents: .date)
                }
            }
            .navigationTitle(L10n.t(.rangeTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t(.actionCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.actionApply)) {
                        onApply(min(start, end), max(start, end))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#if DEBUG
#Preview {
    DashboardView(environment: AppEnvironment.preview())
        .environment(AppEnvironment.preview())
}

#endif
