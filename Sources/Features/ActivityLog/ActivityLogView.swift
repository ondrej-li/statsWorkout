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

    func load(environment: AppEnvironment) async {
        phase = .loading
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
                        "Couldn't load activities",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loading where model.days.isEmpty:
                    ProgressView().controlSize(.large)
                case .loaded where model.days.isEmpty:
                    ContentUnavailableView(
                        "No activities yet",
                        systemImage: "figure.run.circle",
                        description: Text("Workouts recorded in Apple Health for the last six months show up here.")
                    )
                default:
                    list
                }
            }
            .navigationTitle("Activities")
            .navigationDestination(for: ActivitySample.self) { activity in
                ActivityDetailView(activity: activity)
            }
            .task {
                await model.load(environment: environment)
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
                Section(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))) {
                    ForEach(day.activities) { activity in
                        NavigationLink(value: activity) {
                            ActivityRow(activity: activity, formatter: environment.formatter)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#if DEBUG
#Preview {
    ActivityLogView()
        .environment(AppEnvironment.preview())
}
#endif
