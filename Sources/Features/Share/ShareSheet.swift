import SwiftUI
import UIKit

/// The system share sheet, with an image and its caption.
struct ShareSheet: UIViewControllerRepresentable {
    let item: ShareItem

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = []
        if let url = item.fileURL {
            items.append(url)
        } else {
            items.append(item.image)
        }
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension View {
    /// Presents the share sheet for `item`, and an alert when rendering failed.
    func sharePresentation(item: Binding<ShareItem?>, failure: Binding<Bool>) -> some View {
        self
            .sheet(item: item) { item in
                ShareSheet(item: item)
                    .presentationDetents([.medium, .large])
            }
            .alert(L10n.t(.shareErrorTitle), isPresented: failure) {
                Button(L10n.t(.actionCancel), role: .cancel) {}
            } message: {
                Text(L10n.t(.shareErrorBody))
            }
    }
}
