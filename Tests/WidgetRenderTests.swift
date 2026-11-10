import CoreGraphics
import SwiftUI
import Testing
import UIKit
import WidgetKit
@testable import StatsWorkout

@Suite("Widget rendering")
@MainActor
struct WidgetRenderTests {
    private let calendar = TestSupport.calendar(timeZone: "Europe/Prague")

    private func stats(period: PeriodKind = .month, scope: DataScope = .all) -> WidgetStats {
        let now = TestSupport.date(calendar, 2026, 11, 9, 12)
        let sample = WidgetPlaceholder.stats(
            for: WidgetFilters(period: period, scope: scope),
            calendar: calendar,
            now: now
        )
        return WidgetStats(range: sample.range, content: .ready(sample), syncedAt: now)
    }

    /// Nominal widget sizes in points, as iOS lays them out on a 6.1" phone.
    private func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return CGSize(width: 170, height: 170)
        case .systemMedium: return CGSize(width: 364, height: 170)
        default: return CGSize(width: 364, height: 382)
        }
    }

    private func luminanceSpread(_ image: UIImage) -> (mean: Double, deviation: Double)? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 64
        let height = 64
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

    @Test("Every size renders with content", arguments: [WidgetFamily.systemSmall, .systemMedium, .systemLarge])
    func rendersEachSize(family: WidgetFamily) throws {
        let view = StatsWidgetView(
            configuration: WidgetFilters(period: .month),
            stats: stats(),
            rangeTitle: "November 2026",
            familyOverride: family
        )
        // Widget content gets these margins from the system; without them the
        // render would touch the edges and misrepresent the layout.
        .padding(11)
        .frame(width: size(for: family).width, height: size(for: family).height)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .large)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try #require(renderer.uiImage)

        // 170pt at 3x is 510px; a rendering that failed would be a flat rectangle.
        #expect(image.size.width == size(for: family).width)
        let pixels = try #require(luminanceSpread(image))
        #expect(pixels.deviation > 0.05, "the \(family) widget looks blank")
    }

    @Test("Each size gives a metric row to every metric it declares room for")
    func metricCountMatchesSize() {
        let filters = WidgetFilters(period: .month)
        #expect(WidgetLayout.metrics(for: .systemSmall, configuration: filters).count == 1)
        #expect(WidgetLayout.metrics(for: .systemMedium, configuration: filters).count == 3)
        #expect(WidgetLayout.metrics(for: .systemLarge, configuration: filters).count == 5)
    }

    @Test("The chart is drawn at every size, tallest on the large one")
    func chartHeights() {
        #expect(WidgetLayout.showsChart(for: .systemSmall))
        #expect(WidgetLayout.chartHeight(for: .systemSmall) < WidgetLayout.chartHeight(for: .systemMedium))
        #expect(WidgetLayout.chartHeight(for: .systemMedium) < WidgetLayout.chartHeight(for: .systemLarge))
    }

    @Test("A widget without data explains itself instead of showing zeros")
    func emptyStates() throws {
        for content in [WidgetStats.Content.needsApp, .empty] {
            let view = StatsWidgetView(
                configuration: WidgetFilters(),
                stats: WidgetStats(range: WidgetPlaceholder.stats(for: WidgetFilters()).range, content: content, syncedAt: nil),
                rangeTitle: "November 2026",
                familyOverride: .systemMedium
            )
            .frame(width: 364, height: 170)
            .environment(\.colorScheme, .dark)

            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            #expect(renderer.uiImage != nil)
        }
    }
}
