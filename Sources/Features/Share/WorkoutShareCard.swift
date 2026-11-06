import SwiftUI

/// One workout, with the shape of its recording and its numbers.
struct WorkoutShareCard: View {
    let kind: ActivityKind
    let title: String
    let dateText: String
    let timeText: String
    /// Label/value pairs, in the order the detail screen shows them.
    let stats: [(title: String, value: String, systemImage: String)]
    let route: [RoutePoint]

    private var accent: Color { Theme.accent(for: .exerciseDuration) }

    var body: some View {
        ZStack {
            ShareCardBackground(accent: accent)

            VStack(alignment: .leading, spacing: 0) {
                ShareCardHeader(accent: accent)

                Spacer(minLength: 14)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 46, height: 46)
                        .background(accent.opacity(0.18), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(dateText) · \(timeText)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 14)

                ShareRouteTrace(route: route, accent: accent, height: route.count >= 2 ? 268 : 96)

                Spacer(minLength: 16)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 22), GridItem(.flexible(), spacing: 22)],
                    alignment: .leading,
                    spacing: 13
                ) {
                    ForEach(Array(stats.prefix(6).enumerated()), id: \.offset) { _, stat in
                        ShareCardStat(title: stat.title, value: stat.value, systemImage: stat.systemImage)
                    }
                }

                Spacer(minLength: 12)

                ShareCardFooter()
            }
            .padding(ShareCard.padding)
        }
        .frame(width: ShareCard.size.width, height: ShareCard.size.height)
        .environment(\.colorScheme, .dark)
    }
}
