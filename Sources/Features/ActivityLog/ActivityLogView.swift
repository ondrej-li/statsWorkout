import Observation
import SwiftUI

@MainActor
@Observable
final class ActivityLogViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    struct Day: Identifiable {
        let date: Date
        let activities: [ActivitySample]

        var id: Date { date }
    }

    var phase: Phase = .loading
    var days: [Day] = []

    /// True when every workout on screen is generated demo data.
    var showsDemoData: Bool {
        let activities = days.flatMap(\.activities)
        return !activities.isEmpty && activities.allSatisfy { $0.healthKitUUID == nil }
    }

    func load(environment: AppEnvironment) async {
        phase = .loading
        ScreenshotRoute.markLoading("activities")
        do {
            let calendar = environment.calendar
            let now = environment.now()
            let start = calendar.date(byAdding: .day, value: -179, to: now) ?? now
            let activities = try await environment.dataSource.activities(
                in: DateInterval(start: calendar.startOfDay(for: start), end: now)
            )

            let grouped = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.start) }
            days = grouped
                .map { Day(date: $0.key, activities: $0.value.sorted { $0.start > $1.start }) }
                .sorted { $0.date > $1.date }
            phase = .loaded
            ScreenshotRoute.markReady("activities")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

struct ActivityLogView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model = ActivityLogViewModel()
    @State private var path: [ActivitySample] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch model.phase {
                case .failed(let message):
                    ContentUnavailableView(
                        L10n.t(.logErrorTitle),
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loading where model.days.isEmpty:
                    ProgressView().controlSize(.large)
                case .loaded where model.days.isEmpty:
                    ContentUnavailableView(
                        L10n.t(.logEmptyTitle),
                        systemImage: "figure.run.circle",
                        description: Text(L10n.t(.logEmptyBody))
                    )
                default:
                    list
                }
            }
            .navigationTitle(L10n.t(.logTitle))
            .navigationDestination(for: ActivitySample.self) { activity in
                ActivityDetailView(activity: activity, environment: environment)
            }
            // Reloading on the switch keeps the list from showing real workouts
            // while the app is in demo mode, or the other way round.
            .task(id: environment.settings.useMockData) {
                await model.load(environment: environment)
                await environment.resolveWorkoutPlaces(for: model.days.flatMap(\.activities))
                // App Store artwork is captured by opening a workout directly.
                if let index = ScreenshotRoute.workoutIndex {
                    let activities = model.days.flatMap(\.activities)
                    if activities.indices.contains(index) {
                        path = [activities[index]]
                    }
                }
            }
            .refreshable { await model.load(environment: environment) }
        }
    }

    private var list: some View {
        List {
            ForEach(model.days) { day in
                Section(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(environment.locale))) {
                    ForEach(day.activities) { activity in
                        NavigationLink(value: activity) {
                            ActivityRow(
                                activity: activity,
                                title: environment.workoutTitle(for: activity),
                                formatter: environment.formatter
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if model.showsDemoData && !ScreenshotRoute.hidesDemoLabels {
                demoFooter
            }
        }
    }

    /// Demo workouts are generated on device; say so, so a synthetic route is
    /// never mistaken for a recorded one.
    private var demoFooter: some View {
        Label(L10n.t(.demoLogFooter), systemImage: "flask")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

#if DEBUG
#Preview {
    ActivityLogView()
        .environment(AppEnvironment.preview())
}
#endif
