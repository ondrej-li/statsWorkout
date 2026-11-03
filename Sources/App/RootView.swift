import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: ScreenshotRoute.Tab = ScreenshotRoute.tab ?? .stats

    var body: some View {
        TabView(selection: $selection) {
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                DashboardView(environment: environment)
            }
            Tab("Activities", systemImage: "figure.run", value: .activities) {
                ActivityLogView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
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
