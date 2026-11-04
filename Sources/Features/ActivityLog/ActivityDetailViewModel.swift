import Foundation
import Observation

@MainActor
@Observable
final class ActivityDetailViewModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    /// Where the trace on screen came from. Shown to the user, because a
    /// fabricated route must never be able to hide behind real numbers.
    enum RouteProvenance: Equatable {
        case loading
        case demo
        case recorded(points: Int)
        case notRecorded
    }

    let activity: ActivitySample
    private(set) var phase: Phase = .loading
    private(set) var detail = WorkoutDetail()
    private(set) var placeName: String?

    /// The source that recorded this workout, resolved by the caller. It is
    /// passed in rather than looked up here so the detail screen can never pick
    /// a different source from the list that produced the workout.
    private let source: any HealthDataProviding
    private let environment: AppEnvironment
    private let places: any PlaceResolving

    init(
        activity: ActivitySample,
        environment: AppEnvironment,
        source: (any HealthDataProviding)? = nil,
        places: (any PlaceResolving)? = nil
    ) {
        self.activity = activity
        self.environment = environment
        self.source = source ?? environment.dataSource(for: activity)
        self.places = places ?? environment.places
    }

    // MARK: - Presentation

    var formatter: MetricFormatter { environment.formatter }
    var distanceUnit: DistanceUnit { environment.settings.distanceUnit }
    var calendar: Calendar { environment.calendar }

    var title: String { environment.workoutTitle(for: activity) }

    /// True for a generated demo workout: no HealthKit identity means nothing
    /// about it was recorded.
    var isDemo: Bool { activity.healthKitUUID == nil }

    var provenance: RouteProvenance {
        guard phase == .loaded else { return .loading }
        if isDemo { return .demo }
        return detail.hasRoute ? .recorded(points: detail.route.count) : .notRecorded
    }

    var splits: [WorkoutSplit] {
        guard detail.hasRoute else { return [] }
        let splitLength: Double = distanceUnit == .kilometers ? 1_000 : 1_609.344
        // GPS traces are a little longer than the distance HealthKit reports, so
        // splits are laid out along the recorded distance rather than the raw
        // trace length.
        return RouteGeometry.splits(
            of: detail.route,
            splitLength: splitLength,
            totalDistance: activity.distanceMeters
        )
    }

    /// Time span of the recorded trace, for the route details disclosure.
    var traceTimeRange: String? {
        guard let first = detail.route.first?.time, let last = detail.route.last?.time else { return nil }
        return "\(first.formatted(date: .omitted, time: .shortened)) – \(last.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Loading

    func load() async {
        if case .loaded = phase { return }
        phase = .loading

        do {
            detail = try await source.workoutDetail(for: activity)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        // Naming is a nicety: a failed geocode simply leaves it out.
        if environment.workoutPlaces[activity.stableID] == nil,
           let centre = RouteGeometry.centroid(of: detail.route),
           let place = await places.placeName(near: centre) {
            placeName = place
            await environment.rememberPlace(place, for: activity)
        }
    }
}
