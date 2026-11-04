import SwiftUI

enum Theme {
    static func accent(for metric: Metric) -> Color {
        switch metric {
        case .steps: return Color(red: 0.18, green: 0.55, blue: 0.98)
        case .distance: return Color(red: 0.12, green: 0.72, blue: 0.56)
        case .elevationGain: return Color(red: 0.96, green: 0.56, blue: 0.16)
        case .exerciseDuration: return Color(red: 0.82, green: 0.33, blue: 0.72)
        case .activityCount: return Color(red: 0.52, green: 0.42, blue: 0.98)
        }
    }

    static func gradient(for metric: Metric) -> LinearGradient {
        let accent = accent(for: metric)
        return LinearGradient(
            colors: [accent.opacity(0.95), accent.opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    static var screenBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }
}

/// Rounded surface used by every dashboard section.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

/// Small pill showing the relative change against the comparison period.
struct DeltaPill: View {
    let delta: Double?

    var body: some View {
        if let delta {
            let isFlat = abs(delta) < 0.005
            let isPositive = delta >= 0
            let color = isFlat ? Color.secondary : (isPositive ? Color.green : Color.orange)
            let symbol = isFlat ? "arrow.right" : (isPositive ? "arrow.up.right" : "arrow.down.right")
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .heavy))
                Text(delta.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .never).locale(L10n.shared.locale)))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(deltaDescription(delta, isFlat: isFlat, isPositive: isPositive))
        } else {
            Text("—")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityLabel(L10n.t(.comparisonNone))
        }
    }

    private func deltaDescription(_ delta: Double, isFlat: Bool, isPositive: Bool) -> String {
        if isFlat { return L10n.t(.comparisonFlat) }
        let percent = Int((abs(delta) * 100).rounded())
        return isPositive ? L10n.t(.comparisonUp, percent) : L10n.t(.comparisonDown, percent)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .kerning(0.8)
            .foregroundStyle(.secondary)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 120

    var body: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Theme.cardBackground)
            .frame(height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05))
            }
            .shimmer()
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.25), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 320)
                .blendMode(.plusLighter)
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
