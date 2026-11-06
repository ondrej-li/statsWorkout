import SwiftUI

extension View {
    /// Presents the share preview for `item`, and an alert when rendering failed.
    func sharePresentation(item: Binding<ShareItem?>, failure: Binding<Bool>) -> some View {
        self
            .sheet(item: item) { item in
                SharePreviewSheet(item: item)
            }
            .alert(L10n.t(.shareErrorTitle), isPresented: failure) {
                Button(L10n.t(.actionDone), role: .cancel) {}
            } message: {
                Text(L10n.t(.shareErrorBody))
            }
    }
}
