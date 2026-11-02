import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        TabView {
            Tab("Stats", systemImage: "chart.bar.xaxis") {
                DashboardView(environment: environment)
            }
            Tab("Activities", systemImage: "figure.run") {
                ActivityLogView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(AppEnvironment.preview())
}

#endif
