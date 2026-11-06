import Foundation

/// Plain geometry over `RoutePoint`s: distances, bounds, splits.
enum RouteGeometry {
    static let earthRadius: Double = 6_371_000

    static func distance(from a: RoutePoint, to b: RoutePoint) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    static func length(of route: [RoutePoint]) -> Double {
        guard route.count > 1 else { return 0 }
        return zip(route, route.dropFirst()).reduce(0) { $0 + distance(from: $1.0, to: $1.1) }
    }

    /// Centre of the route, used to name the workout ("around Brtnice").
    static func centroid(of route: [RoutePoint]) -> RoutePoint? {
        guard !route.isEmpty else { return nil }
        let latitude = route.reduce(0) { $0 + $1.latitude } / Double(route.count)
        let longitude = route.reduce(0) { $0 + $1.longitude } / Double(route.count)
        return RoutePoint(latitude: latitude, longitude: longitude)
    }

    struct Bounds: Equatable, Sendable {
        var minLatitude: Double
        var maxLatitude: Double
        var minLongitude: Double
        var maxLongitude: Double

        var centre: RoutePoint {
            RoutePoint(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            )
        }

        /// Span in degrees with padding, never smaller than `minimumSpan`.
        func span(padding: Double = 1.5, minimumSpan: Double = 0.004) -> (latitude: Double, longitude: Double) {
            let latitude = max((maxLatitude - minLatitude) * padding, minimumSpan)
            let longitude = max((maxLongitude - minLongitude) * padding, minimumSpan)
            return (latitude, longitude)
        }
    }

    static func bounds(of route: [RoutePoint]) -> Bounds? {
        guard let first = route.first else { return nil }
        return route.dropFirst().reduce(
            Bounds(
                minLatitude: first.latitude, maxLatitude: first.latitude,
                minLongitude: first.longitude, maxLongitude: first.longitude
            )
        ) { bounds, point in
            Bounds(
                minLatitude: min(bounds.minLatitude, point.latitude),
                maxLatitude: max(bounds.maxLatitude, point.latitude),
                minLongitude: min(bounds.minLongitude, point.longitude),
                maxLongitude: max(bounds.maxLongitude, point.longitude)
            )
        }
    }

    /// Splits of `splitLength` metres, interpolating the crossing time so a
    /// partial last split gets the pace it actually had.
    /// - Parameters:
    ///   - splitLength: nominal length of a split (1 km or 1 mile).
    ///   - totalDistance: the distance HealthKit recorded for the workout. A GPS
    ///     trace is usually slightly longer than that, so the splits are laid out
    ///     along this distance and the trace is only used for timing.
    static func splits(
        of route: [RoutePoint],
        splitLength: Double,
        totalDistance: Double? = nil,
        fallbackStart: Date? = nil,
        fallbackDuration: TimeInterval = 0
    ) -> [WorkoutSplit] {
        guard route.count >= 2, splitLength > 0 else { return [] }

        let traceLength = length(of: route)
        let stepLength: Double = {
            guard let totalDistance, totalDistance > 0, traceLength > 0 else { return splitLength }
            let scale = traceLength / totalDistance
            // Only calibrate when the two disagree meaningfully.
            return abs(scale - 1) > 0.02 ? splitLength * scale : splitLength
        }()

        var splits: [WorkoutSplit] = []
        var sinceSplit = 0.0
        var splitIndex = 1
        var currentSplitStart = route[0].time ?? fallbackStart
        var previous = route[0]

        for point in route.dropFirst() {
            let segment = distance(from: previous, to: point)
            guard segment > 0 else { continue }
            var remaining = segment
            var cursor = previous

            while sinceSplit + remaining >= stepLength {
                let needed = stepLength - sinceSplit
                let fraction = needed / segment
                let crossing = interpolate(from: cursor, to: point, fraction: fraction)

                if let start = currentSplitStart, let end = crossing.time {
                    splits.append(
                        WorkoutSplit(index: splitIndex, distance: 1, duration: end.timeIntervalSince(start))
                    )
                }
                splitIndex += 1
                sinceSplit = 0
                currentSplitStart = crossing.time
                remaining -= needed
                cursor = crossing
            }

            sinceSplit += remaining
            previous = point
        }

        // Trailing partial split.
        if sinceSplit > stepLength * 0.15, let start = currentSplitStart {
            let end = route.last?.time ?? start.addingTimeInterval(fallbackDuration)
            let fraction = sinceSplit / stepLength
            splits.append(
                WorkoutSplit(index: splitIndex, distance: fraction, duration: end.timeIntervalSince(start))
            )
        }

        return splits
    }

    // MARK: - Drawing

    /// A point in the unit square, `y` growing downwards like a screen.
    struct UnitPoint: Equatable, Sendable {
        var x: Double
        var y: Double
    }

    /// The route fitted into the unit square with its shape preserved, so a share
    /// card can draw it at any size without the map. Latitude degrees are
    /// shorter than longitude degrees away from the equator, so the two are
    /// scaled by the cosine of the route's latitude before fitting — otherwise a
    /// loop comes out stretched.
    static func unitPolyline(of route: [RoutePoint]) -> [UnitPoint] {
        guard route.count >= 2, let bounds = bounds(of: route) else { return [] }

        let centreLatitude = (bounds.minLatitude + bounds.maxLatitude) / 2 * .pi / 180
        // A degree of longitude shrinks towards the poles.
        let xScale = max(cos(centreLatitude), 0.01)
        let width = (bounds.maxLongitude - bounds.minLongitude) * xScale
        let height = bounds.maxLatitude - bounds.minLatitude
        let extent = max(width, height)
        // A perfectly straight or single-point trace would divide by zero.
        guard extent > 0 else { return [] }

        // Centre the shorter axis so the shape sits in the middle of the square.
        let xInset = (extent - width) / 2 / extent
        let yInset = (extent - height) / 2 / extent

        return route.map { point in
            UnitPoint(
                x: xInset + (point.longitude - bounds.minLongitude) * xScale / extent,
                y: yInset + (bounds.maxLatitude - point.latitude) / extent
            )
        }
    }

    private static func interpolate(from a: RoutePoint, to b: RoutePoint, fraction: Double) -> RoutePoint {
        let time: Date? = {
            guard let start = a.time, let end = b.time else { return a.time ?? b.time }
            return start.addingTimeInterval(end.timeIntervalSince(start) * fraction)
        }()
        return RoutePoint(
            latitude: a.latitude + (b.latitude - a.latitude) * fraction,
            longitude: a.longitude + (b.longitude - a.longitude) * fraction,
            altitude: a.altitude.map { altitude in
                guard let other = b.altitude else { return altitude }
                return altitude + (other - altitude) * fraction
            },
            time: time
        )
    }
}
