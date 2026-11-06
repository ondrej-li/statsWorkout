import SwiftUI

/// Shows the card before anything leaves the app, so nobody posts the wrong
/// period by accident — and so the artwork is visible rather than hidden behind
/// a system sheet full of app icons.
struct SharePreviewSheet: View {
    let item: ShareItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer(minLength: 0)

                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 12)
                    .padding(.horizontal, 6)

                Text(L10n.t(.sharePreviewHint))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)

                shareButton
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 6)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.screenBackground)
            .navigationTitle(L10n.t(.shareButton))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t(.actionDone)) { dismiss() }
                }
            }
        }
    }

    /// The file when there is one — a share target reading a PNG gets a real
    /// thumbnail and a readable name — otherwise the image itself.
    @ViewBuilder
    private var shareButton: some View {
        if let url = item.fileURL {
            ShareLink(item: url) { shareLabel }
        } else {
            ShareLink(
                item: Image(uiImage: item.image),
                preview: SharePreview(L10n.t(.shareButton), image: Image(uiImage: item.image))
            ) {
                shareLabel
            }
        }
    }

    private var shareLabel: some View {
        Label(L10n.t(.shareButton), systemImage: "square.and.arrow.up")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}
