import SwiftUI

@main
struct StatsWorkoutApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}
