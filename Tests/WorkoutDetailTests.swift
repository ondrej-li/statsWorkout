import Foundation
import Testing
@testable import StatsWorkout

@Suite("Workout naming")
struct WorkoutNamingTests {
    private let calendar = TestSupport.calendar()
    private var naming: WorkoutNaming { WorkoutNaming(calendar: calendar) }

    private func activity(_ kind: ActivityKind, hour: Int) -> ActivitySample {
        let start = TestSupport.date(calendar, 2026, 11, 3, hour)
        return ActivitySample(kind: kind, start: start, end: start.addingTimeInterval(3_600))
    }

    @Test("Time of day boundaries")
    func timeOfDay() {
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 4, 59), calendar: calendar) == .night)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 5, 0), calendar: calendar) == .morning)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 11, 59), calendar: calendar) == .morning)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 12, 0), calendar: calendar) == .afternoon)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 16, 59), calendar: calendar) == .afternoon)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 17, 0), calendar: calendar) == .evening)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 21, 59), calendar: calendar) == .evening)
        #expect(TimeOfDay.at(TestSupport.date(calendar, 2026, 11, 3, 22, 0), calendar: calendar) == .night)
    }

    @Test("Titles read the way a person would describe the workout")
    func titles() {
        #expect(naming.title(for: activity(.walking, hour: 7), place: "Brtnice")
            == "Your morning walk around Brtnice")
        #expect(naming.title(for: activity(.running, hour: 23), place: "Okříšky")
            == "Your night run around Okříšky")
        #expect(naming.title(for: activity(.cycling, hour: 15), place: "Třebíč")
            == "Your afternoon ride around Třebíč")
    }

    @Test("A workout without a place still gets a title")
    func withoutPlace() {
        #expect(naming.title(for: activity(.strength, hour: 18), place: nil)
            == "Your evening strength workout")
        #expect(naming.title(for: activity(.yoga, hour: 9), place: "   ")
            == "Your morning yoga session")
    }

    @Test("Placemark names are reduced to the settlement")
    func placeCleaning() {
        #expect(WorkoutNaming.cleanedPlace("Brtnice, Czechia") == "Brtnice")
        #expect(WorkoutNaming.cleanedPlace("  brtnice ") == "Brtnice")
        #expect(WorkoutNaming.cleanedPlace("") == nil)
        #expect(WorkoutNaming.cleanedPlace(nil) == nil)
    }

    @Test("Short title for lists")
    func shortTitles() {
        #expect(naming.shortTitle(for: activity(.hiking, hour: 6), place: "Jihlava")
            == "Morning hike around Jihlava")
    }
}

@Suite("Route geometry")
struct RouteGeometryTests {
    private func point(_ latitude: Double, _ longitude: Double, minutes: Double? = nil) -> RoutePoint {
        RoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: nil,
            time: minutes.map { TestSupport.date(TestSupport.calendar(), 2026, 11, 3).addingTimeInterval($0 * 60) }
        )
    }

    @Test("One degree of latitude is about 111 km")
    func distance() {
        let metres = RouteGeometry.distance(from: point(49, 15), to: point(50, 15))
        #expect(metres > 110_000 && metres < 112_000)
    }

    @Test("Centroid and bounds cover the route")
    func centroidAndBounds() {
        let route = [point(49.30, 15.60), point(49.32, 15.64), point(49.28, 15.62)]
        let centre = try? #require(RouteGeometry.centroid(of: route))
        #expect(abs((centre?.latitude ?? 0) - 49.30) < 0.0001)
        #expect(abs((centre?.longitude ?? 0) - 15.62) < 0.0001)

        let bounds = RouteGeometry.bounds(of: route)
        #expect(bounds?.minLatitude == 49.28)
        #expect(bounds?.maxLongitude == 15.64)
        if let span = bounds?.span() {
            #expect(span.latitude > 0.04)
        } else {
            Issue.record("Expected bounds for a non-empty route")
        }
    }

    /// 4 km straight north over 20 minutes, sampled every 100 m.
    private func straightRoute(kilometres: Double, minutes: Double) -> [RoutePoint] {
        let steps = Int(kilometres * 10)
        let metresPerStep = 100.0
        let degreesPerStep = metresPerStep / 111_000
        return (0...steps).map { index in
            let progress = Double(index) / Double(steps)
            return RoutePoint(
                latitude: 49.30 + degreesPerStep * Double(index),
                longitude: 15.6,
                altitude: 400,
                time: TestSupport.date(TestSupport.calendar(), 2026, 11, 3)
                    .addingTimeInterval(minutes * 60 * progress)
            )
        }
    }

    @Test("Splits are even for an even route")
    func evenSplits() {
        let splits = RouteGeometry.splits(of: straightRoute(kilometres: 4, minutes: 20), splitLength: 1_000)

        #expect(splits.count == 4)
        #expect(splits.allSatisfy { abs($0.duration - 300) < 3 })
        #expect(splits.map(\.index) == [1, 2, 3, 4])
    }

    @Test("A trailing partial split keeps its real pace")
    func partialSplit() {
        let splits = RouteGeometry.splits(of: straightRoute(kilometres: 2.5, minutes: 15), splitLength: 1_000)

        #expect(splits.count == 3)
        #expect(abs((splits.last?.distance ?? 0) - 0.5) < 0.02)
        #expect(abs((splits.last?.duration ?? 0) - 180) < 3)
        #expect(abs((splits.last?.pace ?? 0) - 360) < 8)
    }

    @Test("Routes shorter than a split produce nothing")
    func shortRoute() {
        #expect(RouteGeometry.splits(of: straightRoute(kilometres: 0.05, minutes: 1), splitLength: 1_000).isEmpty)
    }
}
