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

    var naming: WorkoutNaming {
        WorkoutNaming(calendar: environment.calendar)
    }

    var title: String {
        naming.title(for: activity, place: placeName)
    }

    var splits: [WorkoutSplit] {
        guard detail.hasRoute else { return [] }
        let splitLength: Double = environment.settings.distanceUnit == .kilometers ? 1_000 : 1_609.344
        return RouteGeometry.splits(of: detail.route, splitLength: splitLength)
    }

    func load() async {
        if case .loaded = phase { return }
        phase = .loading
        do {
            let source = environment.dataSource
            detail = try await source.workoutDetail(for: activity)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        // Naming is a nicety: a failed geocode simply leaves it out.
        if let centre = RouteGeometry.centroid(of: detail.route) {
            placeName = await places.placeName(near: centre)
        }
    }
}
