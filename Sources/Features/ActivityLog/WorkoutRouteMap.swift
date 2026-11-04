import MapKit
import SwiftUI

/// The route of a workout on a map, framed to the route itself.
struct WorkoutRouteMap: View {
    let route: [RoutePoint]
    var tint: Color = Theme.accent(for: .distance)
    var height: CGFloat = 240

    var body: some View {
        Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: coordinates)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            // A loop starts where it finishes; two markers there just look messy.
            if let start = coordinates.first, routeLengthBetweenStartAndFinish > 40 {
                Marker("Start", systemImage: "flag.fill", coordinate: start)
                    .tint(.green)
            }
            if let finish = coordinates.last, coordinates.count > 1 {
                Marker("Finish", systemImage: "flag.checkered", coordinate: finish)
                    .tint(.orange)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        }
        .accessibilityLabel("Workout route map")
    }

    private var routeLengthBetweenStartAndFinish: Double {
        guard let first = route.first, let last = route.last else { return 0 }
        return RouteGeometry.distance(from: first, to: last)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var region: MKCoordinateRegion {
        guard let bounds = RouteGeometry.bounds(of: route) else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 49.3, longitude: 15.7),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        let span = bounds.span()
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: bounds.centre.latitude,
                longitude: bounds.centre.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: span.latitude, longitudeDelta: span.longitude)
        )
    }
}

#if DEBUG
#Preview {
    WorkoutRouteMap(
        route: MockHealthData.workoutDetail(
            for: ActivitySample(
                kind: .running,
                start: Date(),
                end: Date().addingTimeInterval(3_600),
                distanceMeters: 9_000
            ),
            calendar: .current,
            seed: 7
        ).route
    )
    .padding()
}
#endif
