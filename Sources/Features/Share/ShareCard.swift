import SwiftUI

/// The artwork shared to Facebook, Instagram, Messenger or WhatsApp.
///
/// Everything here is drawn from values the screen already computed — no
/// HealthKit call and no new permission — so a card always matches what the user
/// was looking at. Sizes are in points and rendered at scale 2, which lands on
/// 1080 × 1350 px: the 4:5 shape Instagram, Facebook and WhatsApp all crop to
/// without cutting anything off.
enum ShareCard {
    static let size = CGSize(width: 540, height: 675)
    static let pixelScale: CGFloat = 2

    static let backgroundTop = Color(red: 0.07, green: 0.11, blue: 0.20)
    static let backgroundBottom = Color(red: 0.03, green: 0.04, blue: 0.09)

    static let padding: CGFloat = 32
}

/// Dark gradient card with a glow in the metric's colour, matching the app.
struct ShareCardBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ShareCard.backgroundTop, ShareCard.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [accent.opacity(0.42), .clear],
                center: UnitPoint(x: 0.12, y: 0.02),
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [accent.opacity(0.20), .clear],
                center: UnitPoint(x: 0.95, y: 0.98),
                startRadius: 0,
                endRadius: 380
            )
        }
    }
}

/// Wordmark and app name, so a shared frame says where it came from.
struct ShareCardHeader: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
            Text("StatsWorkout")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .kerning(0.4)
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 0)
        }
    }
}

struct ShareCardFooter: View {
    var body: some View {
        HStack(spacing: 6) {
            Text(L10n.t(.shareCardTagline))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 0)
            Text("stats-workout.ondralinek.cz")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.32))
        }
    }
}

/// One label/value pair in the small grids.
struct ShareCardStat: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .kerning(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bars for the buckets of the period, with the average as a dashed rule.
///
/// Drawn with plain shapes rather than Swift Charts: the card is rendered to an
/// image off screen, and this way the result is identical every time.
struct ShareBarChart: View {
    /// Plot values, already converted to the display unit.
    let values: [Double]
    let average: Double
    /// Evenly spaced ticks: index into `values` and the label to draw.
    let labels: [(index: Int, text: String)]
    let accent: Color
    var height: CGFloat = 132

    private var maximum: Double { max(values.max() ?? 0, average, 0.0001) }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let maxValue = maximum * 1.16
                let count = max(values.count, 1)
                let spacing: CGFloat = count > 16 ? 2 : 4
                let barWidth = max(1.5, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)

                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            let fraction = max(0, min(1, value / maxValue))
                            RoundedRectangle(cornerRadius: min(3, barWidth / 2.5), style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.45)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: barWidth, height: max(fraction * proxy.size.height, value > 0 ? 2 : 0))
                        }
                    }

                    if average > 0 {
                        let y = proxy.size.height - (average / maxValue) * proxy.size.height
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                        }
                        .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
            }
            .frame(height: height)

            // Ticks sit under the bar they belong to rather than in equal
            // columns, and the outer two are kept inside the card.
            GeometryReader { proxy in
                ForEach(labels, id: \.index) { tick in
                    let centre = (Double(tick.index) + 0.5) / Double(max(values.count, 1))
                    let x = min(max(centre * proxy.size.width, 16), proxy.size.width - 16)
                    Text(tick.text)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 40)
                        .position(x: x, y: proxy.size.height / 2)
                }
            }
            .frame(height: 14)
        }
    }
}

/// The route as a line, with its start and finish marked.
///
/// A stylised trace rather than a map: it is the shape of the recording, it
/// carries no street names or place labels to a social network, and it renders
/// identically without a network connection.
struct ShareRouteTrace: View {
    let route: [RoutePoint]
    let accent: Color
    var height: CGFloat = 300

    var body: some View {
        let points = RouteGeometry.unitPolyline(of: route)

        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))

            if points.count >= 2 {
                GeometryReader { proxy in
                    let inset: CGFloat = 26
                    let width = proxy.size.width - inset * 2
                    let traceHeight = proxy.size.height - inset * 2
                    let cgPoints = points.map {
                        CGPoint(x: inset + $0.x * width, y: inset + $0.y * traceHeight)
                    }

                    ZStack {
                        tracePath(cgPoints)
                            .stroke(
                                accent.opacity(0.28),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                            )

                        tracePath(cgPoints)
                            .stroke(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                            )

                        if let first = cgPoints.first {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .position(first)
                        }
                        if let last = cgPoints.last {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 12, height: 12)
                                .position(last)
                        }
                    }
                }
            } else {
                Image(systemName: "map")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func tracePath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
    }
}
