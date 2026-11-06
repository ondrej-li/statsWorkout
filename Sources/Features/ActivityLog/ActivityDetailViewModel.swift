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
    var locale: Locale { environment.locale }

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
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        return "\(first.formatted(style)) – \(last.formatted(style))"
    }

    // MARK: - Rows

    /// The numbers the detail screen and the share card both show, built once so
    /// they can never disagree.
    struct MetricRow: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
        let systemImage: String
    }

    var metricRows: [MetricRow] {
        var rows: [MetricRow] = [
            MetricRow(
                id: "duration",
                title: L10n.t(.detailDuration),
                value: formatter.duration(minutes: activity.duration / 60),
                systemImage: "timer"
            )
        ]

        if let distance = activity.distanceMeters, distance > 0 {
            rows.append(
                MetricRow(
                    id: "distance",
                    title: L10n.t(.detailDistance),
                    value: formatter.string(distance, for: .distance),
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                )
            )
            if let pace = averagePace {
                rows.append(
                    MetricRow(id: "pace", title: L10n.t(.detailAveragePace), value: pace, systemImage: "speedometer")
                )
            }
        }
        if let elevation = activity.elevationGainMeters, elevation > 0 {
            rows.append(
                MetricRow(
                    id: "elevation",
                    title: L10n.t(.detailElevation),
                    value: formatter.string(elevation, for: .elevationGain),
                    systemImage: "mountain.2"
                )
            )
        }
        if let steps = activity.stepCount, steps > 0 {
            rows.append(
                MetricRow(
                    id: "steps",
                    title: L10n.t(.detailSteps),
                    value: formatter.heroString(steps, for: .steps),
                    systemImage: "shoeprints.fill"
                )
            )
        }
        if let energy = detail.energyKilocalories ?? activity.activeEnergyKilocalories, energy > 0 {
            rows.append(
                MetricRow(
                    id: "energy",
                    title: L10n.t(.detailEnergy),
                    value: L10n.t(.valueWithUnit, "\(Int(energy.rounded()))", L10n.t(.unitKcal)),
                    systemImage: "flame"
                )
            )
        }
        if let heart = detail.averageHeartRate {
            rows.append(
                MetricRow(
                    id: "heart",
                    title: L10n.t(.detailAverageHeartRate),
                    value: formatter.heartRate(heart),
                    systemImage: "heart"
                )
            )
        }
        if let heart = detail.maximumHeartRate {
            rows.append(
                MetricRow(
                    id: "maxHeart",
                    title: L10n.t(.detailMaxHeartRate),
                    value: formatter.heartRate(heart),
                    systemImage: "heart.circle"
                )
            )
        }
        return rows
    }

    private var averagePace: String? {
        guard let distance = activity.distanceMeters, distance > 0, activity.duration > 0 else {
            return nil
        }
        let unit = distanceUnit
        let units = unit.value(fromMeters: distance)
        guard units > 0 else { return nil }
        return formatter.pace(activity.duration / units, unit: unit)
    }

    /// Date and time of the workout, formatted for the chosen language.
    var dateText: String {
        activity.start.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale))
    }

    var timeText: String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)
        return "\(activity.start.formatted(style)) – \(activity.end.formatted(style))"
    }

    /// Ready-to-share artwork of this workout.
    func shareItem() -> ShareItem? {
        ShareComposer.workout(
            activity: activity,
            metricRows: metricRows,
            route: detail.route,
            title: title,
            dateText: dateText,
            timeText: timeText,
            locale: locale
        )
    }

    // MARK: - Loading

    var canRequestRouteAccess: Bool {
        !isDemo && !detail.hasRoute
    }

    /// Re-asks HealthKit for access. Adding route read access to the app's set
    /// makes the system sheet appear again for the new type.
    func requestRouteAccess() async {
        phase = .loading
        try? await environment.healthKit.requestAuthorization()
        await reload()
    }

    func reload() async {
        phase = .loading
        detail = WorkoutDetail()
        await load(force: true)
    }

    func load(force: Bool = false) async {
        if case .loaded = phase, !force { return }
        phase = .loading
        ScreenshotRoute.markLoading("detail")

        do {
            detail = try await source.workoutDetail(for: activity)
            phase = .loaded
            ScreenshotRoute.markReady("detail")
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
