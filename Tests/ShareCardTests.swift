import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import StatsWorkout

@Suite("Sharing")
@MainActor
struct ShareCardTests {
    /// Pixel size, which is what a social network sees; `UIImage.size` is in points.
    private func pixelSize(_ image: UIImage) -> CGSize? {
        guard let cgImage = image.cgImage else { return nil }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    private func lumens(_ image: UIImage) -> (mean: Double, contrast: Double)? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 64
        let height = 80
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = pixels.withUnsafeMutableBytes({ buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var values: [Double] = []
        values.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            values.append(
                (0.2126 * Double(pixels[index])
                    + 0.7152 * Double(pixels[index + 1])
                    + 0.0722 * Double(pixels[index + 2])) / 255
            )
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (mean, variance.squareRoot())
    }

    @Test("The dashboard card is 1080 × 1350 and actually has content")
    func dashboardCardRenders() throws {
        let stats = PreviewStats.sample()
        let formatter = MetricFormatter(units: .metric, locale: Locale(identifier: "en_US"))
        let periodFormatter = PeriodFormatter(calendar: TestSupport.calendar(), locale: Locale(identifier: "en_US"))

        let item = try #require(
            ShareComposer.dashboard(
                stats: stats,
                metric: .steps,
                scope: .all,
                title: "October 2026",
                subtitle: periodFormatter.progressCaption(for: stats),
                formatter: formatter,
                periodFormatter: periodFormatter
            )
        )

        // 4:5, the shape Instagram, Facebook and WhatsApp crop to.
        #expect(pixelSize(item.image) == CGSize(width: 1080, height: 1350))

        // A blank or unrendered card is a flat rectangle; this one has a
        // gradient, bars and text, so it varies and is not pitch black.
        let stats2 = try #require(lumens(item.image))
        #expect(stats2.mean > 0.02)
        #expect(stats2.contrast > 0.05)

        // The file is what the share sheet hands over: a readable name and a
        // PNG a social app can read.
        let url = try #require(item.fileURL)
        #expect(url.pathExtension == "png")
        #expect(url.lastPathComponent.contains("October 2026"))
        #expect(FileManager.default.fileExists(atPath: url.path))
        let onDisk = try #require(UIImage(contentsOfFile: url.path))
        #expect(pixelSize(onDisk) == CGSize(width: 1080, height: 1350))
    }

    @Test("The workout card is 1080 × 1350 with the route drawn in")
    func workoutCardRenders() throws {
        let activity = ActivitySample(
            kind: .running,
            start: TestSupport.date(TestSupport.calendar(), 2026, 11, 3, 7),
            end: TestSupport.date(TestSupport.calendar(), 2026, 11, 3, 8),
            distanceMeters: 9_400,
            elevationGainMeters: 120,
            stepCount: 11_200,
            activeEnergyKilocalories: 610
        )
        let route = (0..<40).map { index in
            let progress = Double(index) / 39
            return RoutePoint(
                latitude: 49.30 + sin(progress * .pi * 2) * 0.01,
                longitude: 15.60 + cos(progress * .pi * 2) * 0.01
            )
        }

        let item = try #require(
            ShareComposer.workout(
                activity: activity,
                metricRows: [
                    .init(id: "duration", title: "Duration", value: "1h 0m", systemImage: "timer"),
                    .init(id: "distance", title: "Distance", value: "9.40 km", systemImage: "ruler")
                ],
                route: route,
                title: "Your morning run around Brtnice",
                dateText: "Tuesday, November 3, 2026",
                timeText: "7:00 – 8:00",
                locale: Locale(identifier: "en_US")
            )
        )

        #expect(pixelSize(item.image) == CGSize(width: 1080, height: 1350))
        let pixels = try #require(lumens(item.image))
        #expect(pixels.mean > 0.02)

        let url = try #require(item.fileURL)
        #expect(url.lastPathComponent.contains("Your morning run around Brtnice"))
    }

    @Test("A workout without a route still renders a card")
    func workoutWithoutRoute() throws {
        let activity = ActivitySample(
            kind: .strength,
            start: TestSupport.date(TestSupport.calendar(), 2026, 11, 3, 18),
            end: TestSupport.date(TestSupport.calendar(), 2026, 11, 3, 19)
        )
        let item = try #require(
            ShareComposer.workout(
                activity: activity,
                metricRows: [.init(id: "duration", title: "Duration", value: "1h", systemImage: "timer")],
                route: [],
                title: "Your evening strength workout",
                dateText: "Tuesday, November 3, 2026",
                timeText: "6:00 PM – 7:00 PM",
                locale: Locale(identifier: "en_US")
            )
        )
        #expect(pixelSize(item.image) == CGSize(width: 1080, height: 1350))
    }

    @Test("Axis ticks are a handful of unique, in-range labels")
    func axisTicks() {
        let stats = PreviewStats.sample()
        let periodFormatter = PeriodFormatter(calendar: TestSupport.calendar(), locale: Locale(identifier: "en_US"))
        let ticks = ShareComposer.axisTicks(for: stats, periodFormatter: periodFormatter)

        #expect(!ticks.isEmpty)
        #expect(ticks.count <= 4)
        #expect(Set(ticks.map(\.index)).count == ticks.count)
        #expect(ticks.allSatisfy { $0.index >= 0 && $0.index < stats.buckets.count })
        #expect(ticks.allSatisfy { !$0.text.isEmpty })
    }
}

@Suite("Route drawing")
struct RoutePolylineTests {
    @Test("A straight east-west trace fills the square horizontally")
    func straightLine() {
        let route = [
            RoutePoint(latitude: 49.30, longitude: 15.60),
            RoutePoint(latitude: 49.30, longitude: 15.62)
        ]
        let points = RouteGeometry.unitPolyline(of: route)
        #expect(points.count == 2)
        #expect(abs(points[0].x) < 0.0001)
        #expect(abs(points[1].x - 1) < 0.0001)
        // A line has no height, so it is centred rather than sitting at an edge.
        #expect(abs(points[0].y - 0.5) < 0.0001)
        #expect(abs(points[1].y - 0.5) < 0.0001)
    }

    @Test("The shape is preserved: a square loop stays square on screen")
    func squareLoop() {
        // At 49° a degree of longitude is ~0.65 of a degree of latitude, so a
        // loop that is square on the ground needs a wider longitude span.
        let latitudeSpan = 0.01
        let longitudeSpan = latitudeSpan / cos(49.3 * .pi / 180)
        let route = [
            RoutePoint(latitude: 49.30, longitude: 15.60),
            RoutePoint(latitude: 49.30, longitude: 15.60 + longitudeSpan),
            RoutePoint(latitude: 49.30 + latitudeSpan, longitude: 15.60 + longitudeSpan),
            RoutePoint(latitude: 49.30 + latitudeSpan, longitude: 15.60)
        ]
        let points = RouteGeometry.unitPolyline(of: route)

        let width = points[1].x - points[0].x
        let height = points[0].y - points[2].y
        #expect(abs(width - height) < 0.01)
        #expect(abs(width - 1) < 0.01)
    }

    @Test("Degenerate traces produce nothing rather than dividing by zero")
    func degenerate() {
        #expect(RouteGeometry.unitPolyline(of: []).isEmpty)
        #expect(RouteGeometry.unitPolyline(of: [RoutePoint(latitude: 49, longitude: 15)]).isEmpty)
        #expect(RouteGeometry.unitPolyline(of: [
            RoutePoint(latitude: 49, longitude: 15),
            RoutePoint(latitude: 49, longitude: 15)
        ]).isEmpty)
    }
}
