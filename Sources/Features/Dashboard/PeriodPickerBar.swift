import SwiftUI

struct PeriodPickerBar: View {
    let selection: PeriodKind
    let onSelect: (PeriodKind) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(PeriodKind.allCases) { kind in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { onSelect(kind) }
                    } label: {
                        Text(kind.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection == kind ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(selection == kind ? Theme.accent(for: .steps) : Color.primary.opacity(0.07))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == kind ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

#Preview {
    VStack {
        PeriodPickerBar(selection: .month) { _ in }
        PeriodPickerBar(selection: .custom) { _ in }
    }
    .padding()
}
