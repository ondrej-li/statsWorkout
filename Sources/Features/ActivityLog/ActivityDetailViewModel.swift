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

    let activity: ActivitySample
    private(set) var phase: Phase = .loading
    private(set) var detail = WorkoutDetail()
    private(set) var placeName: String?

    private let environment: AppEnvironment
    private let places: any PlaceResolving

    init(activity: ActivitySample, environment: AppEnvironment, places: (any PlaceResolving)? = nil) {
        self.activity = activity
        self.environment = environment
        self.places = places ?? environment.places
    }

    var formatter: MetricFormatter { environment.formatter }

    /// True for a generated demo workout: no HealthKit identity means nothing
    /// about it was recorded.
    var isDemo: Bool { activity.healthKitUUID == nil }

    var naming: WorkoutNaming {
        WorkoutNaming(calendar: environment.calendar)
    }

    var title: String {
        environment.workoutTitle(for: activity)
    }

    var splits: [WorkoutSplit] {
        guard detail.hasRoute else { return [] }
        let splitLength: Double = environment.settings.distanceUnit == .kilometers ? 1_000 : 1_609.344
        // GPS traces are a little longer than the distance HealthKit reports, so
        // splits are laid out along the recorded distance rather than the raw
        // trace length.
        return RouteGeometry.splits(
            of: detail.route,
            splitLength: splitLength,
            totalDistance: activity.distanceMeters
        )
    }

    func load() async {
        if case .loaded = phase { return }
        phase = .loading
        do {
            // Never mix sources: a real workout is read from HealthKit even when
            // demo data is switched on elsewhere in the app.
            let source = environment.dataSource(for: activity)
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
