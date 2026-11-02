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

    var body: some View {
        NavigationStack {
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
            .task { await model.load(environment: environment) }
            .refreshable { await model.load(environment: environment) }
        }
    }

    private var list: some View {
        List {
            ForEach(model.days) { day in
                Section(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))) {
                    ForEach(day.activities) { activity in
                        NavigationLink {
                            ActivityDetailView(activity: activity, formatter: environment.formatter)
                        } label: {
                            ActivityRow(activity: activity, formatter: environment.formatter)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ActivityDetailView: View {
    let activity: ActivitySample
    let formatter: MetricFormatter

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: activity.kind.systemImage)
                                .font(.title2)
                                .foregroundStyle(Theme.accent(for: .exerciseDuration))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.kind.title).font(.title3.weight(.semibold))
                                Text(activity.start.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider().opacity(0.5)

                        row("Duration", formatter.duration(minutes: activity.duration / 60))
                        if let distance = activity.distanceMeters {
                            row("Distance", formatter.string(distance, for: .distance))
                        }
                        if let elevation = activity.elevationGainMeters {
                            row("Elevation gain", formatter.string(elevation, for: .elevationGain))
                        }
                        if let energy = activity.activeEnergyKilocalories {
                            row("Energy", "\(Int(energy.rounded())) kcal")
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }
}

#if DEBUG
#Preview {
    ActivityLogView()
        .environment(AppEnvironment.preview())
}

#endif
